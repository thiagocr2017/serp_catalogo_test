-- Añadir soporte a borradores en documentos de inventario
--
-- El RPC actual create_and_confirm_inventory_document siempre crea
-- documentos CONFIRMED y genera movimientos de inventario. Para permitir
-- el flujo de transferencias (BORRADOR -> DESPACHADA -> EN_TRANSITO -> RECIBIDA)
-- y conteos (BORRADOR -> REVIEW -> CONFIRMED), se añade:
-- 1. Parámetro p_draft a create_and_confirm_inventory_document
-- 2. RPC confirm_inventory_document para confirmar un borrador

-- 1. Extender create_and_confirm_inventory_document con p_draft
drop function if exists public.create_and_confirm_inventory_document(
  uuid, inventory_document_type, jsonb, uuid, uuid, uuid, uuid,
  text, text, text, text, text
);

create or replace function public.create_and_confirm_inventory_document(
  p_command_id uuid,
  p_document_type inventory_document_type,
  p_lines jsonb,
  p_origin_warehouse_id uuid,
  p_origin_location_id uuid,
  p_destination_warehouse_id uuid,
  p_destination_location_id uuid,
  p_external_reference text,
  p_notes text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text,
  p_draft boolean default false
) returns public.inventory_documents
language plpgsql security definer set search_path = '' as $$
declare
  existing_document public.inventory_documents;
  created_document public.inventory_documents;
  created_line public.inventory_document_lines;
  origin_location public.inventory_locations;
  destination_location public.inventory_locations;
  line jsonb;
  line_quantity integer;
  movement_quantity integer;
  v_status public.inventory_document_status;
  v_confirmed_at timestamptz;
begin
  select d.* into existing_document
  from public.inventory_documents d
  where d.command_id = p_command_id;
  if found then return existing_document; end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) = 0 then
    raise exception 'El documento necesita al menos un producto';
  end if;

  if p_origin_location_id is not null then
    select * into origin_location from public.inventory_locations
    where id = p_origin_location_id and is_active;
  else
    origin_location := public.default_inventory_location(p_origin_warehouse_id);
  end if;
  if p_destination_location_id is not null then
    select * into destination_location from public.inventory_locations
    where id = p_destination_location_id and is_active;
  else
    destination_location := public.default_inventory_location(p_destination_warehouse_id);
  end if;

  if p_document_type in ('TRANSFER', 'SALE_DISPATCH', 'SUPPLIER_RETURN', 'CONSIGNMENT')
     and origin_location.id is null then
    raise exception 'No existe una ubicación de origen activa';
  end if;
  if p_document_type in ('OPENING', 'ADJUSTMENT', 'TRANSFER', 'PURCHASE_RECEIPT', 'CUSTOMER_RETURN')
     and destination_location.id is null then
    raise exception 'No existe una ubicación de destino activa';
  end if;
  if p_document_type = 'TRANSFER' and origin_location.id = destination_location.id then
    raise exception 'El origen y el destino del traslado deben ser diferentes';
  end if;

  -- Determinar estado inicial
  if p_draft then
    v_status := 'BORRADOR';
    v_confirmed_at := null;
  else
    v_status := 'CONFIRMED';
    v_confirmed_at := now();
  end if;

  insert into public.inventory_documents (
    command_id, document_number, document_type, status,
    origin_warehouse_id, origin_location_id,
    destination_warehouse_id, destination_location_id,
    external_reference, notes, confirmed_at,
    created_by, created_device_name, created_device_identifier
  ) values (
    p_command_id,
    public.inventory_document_prefix(p_document_type) || '-' ||
      lpad(nextval('public.inventory_document_number_seq')::text, 8, '0'),
    p_document_type, v_status,
    origin_location.warehouse_id, origin_location.id,
    destination_location.warehouse_id, destination_location.id,
    nullif(trim(p_external_reference), ''), nullif(trim(p_notes), ''),
    v_confirmed_at,
    p_actor_name, p_device_name, p_device_identifier
  ) returning * into created_document;

  -- Insertar líneas
  for line in select value from jsonb_array_elements(p_lines)
  loop
    line_quantity := (line ->> 'quantity')::integer;
    if line_quantity = 0 then raise exception 'La cantidad no puede ser cero'; end if;

    insert into public.inventory_document_lines (
      document_id, product_id, quantity, notes
    ) values (
      created_document.id, (line ->> 'product_id')::uuid,
      line_quantity, nullif(trim(line ->> 'notes'), '')
    ) returning * into created_line;
  end loop;

  -- Solo crear movimientos de inventario si NO es borrador
  if not p_draft then
    for line in select value from jsonb_array_elements(p_lines)
    loop
      line_quantity := (line ->> 'quantity')::integer;
      if line_quantity = 0 then raise exception 'La cantidad no puede ser cero'; end if;

      if p_document_type = 'TRANSFER' then
        insert into public.inventory_transactions (
          product_id, warehouse_id, location_id, command_id, quantity, reason,
          document_id, document_line_id, notes, actor_name,
          device_name, device_identifier
        ) values (
          (line ->> 'product_id')::uuid,
          origin_location.warehouse_id,
          origin_location.id,
          case when jsonb_array_length(p_lines) = 1 then p_command_id
               else gen_random_uuid() end,
          -abs(line_quantity),
          'TRANSFER_OUT',
          created_document.id, created_line.id, created_document.document_number,
          p_actor_name, p_device_name, p_device_identifier
        );

        insert into public.inventory_transactions (
          product_id, warehouse_id, location_id, command_id, quantity, reason,
          document_id, document_line_id, notes, actor_name,
          device_name, device_identifier
        ) values (
          (line ->> 'product_id')::uuid,
          destination_location.warehouse_id,
          destination_location.id,
          case when jsonb_array_length(p_lines) = 1 then p_command_id
               else gen_random_uuid() end,
          abs(line_quantity),
          'TRANSFER_IN',
          created_document.id, created_line.id, created_document.document_number,
          p_actor_name, p_device_name, p_device_identifier
        );
      else
        movement_quantity := case p_document_type
          when 'SALE_DISPATCH' then -abs(line_quantity)
          when 'SUPPLIER_RETURN' then -abs(line_quantity)
          when 'CONSIGNMENT' then -abs(line_quantity)
          when 'ADJUSTMENT' then line_quantity
          else abs(line_quantity)
        end;
        insert into public.inventory_transactions (
          product_id, warehouse_id, location_id, command_id, quantity, reason,
          document_id, document_line_id, notes, actor_name,
          device_name, device_identifier
        ) values (
          (line ->> 'product_id')::uuid,
          case when movement_quantity < 0 then origin_location.warehouse_id
               else destination_location.warehouse_id end,
          case when movement_quantity < 0 then origin_location.id
               else destination_location.id end,
          case when jsonb_array_length(p_lines) = 1 then p_command_id
               else gen_random_uuid() end,
          movement_quantity,
          case p_document_type
            when 'OPENING' then 'INITIAL_STOCK'::public.inventory_transaction_reason
            when 'ADJUSTMENT' then 'ADJUSTMENT'::public.inventory_transaction_reason
            when 'PURCHASE_RECEIPT' then 'PURCHASE'::public.inventory_transaction_reason
            when 'CUSTOMER_RETURN' then 'RETURN'::public.inventory_transaction_reason
            else 'SALE'::public.inventory_transaction_reason
          end,
          created_document.id, created_line.id, created_document.document_number,
          p_actor_name, p_device_name, p_device_identifier
        );
      end if;
    end loop;
  end if;

  return created_document;
end;
$$;

revoke all on function public.create_and_confirm_inventory_document(
  uuid, inventory_document_type, jsonb, uuid, uuid, uuid, uuid,
  text, text, text, text, text, boolean
) from public;
grant execute on function public.create_and_confirm_inventory_document(
  uuid, inventory_document_type, jsonb, uuid, uuid, uuid, uuid,
  text, text, text, text, text, boolean
) to anon, authenticated;

-- 2. RPC para confirmar un borrador (crea los movimientos)
create or replace function public.confirm_inventory_document(
  p_document_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.inventory_documents
language plpgsql security definer set search_path = '' as $$
declare
  v_document public.inventory_documents;
  v_line public.inventory_document_lines%rowtype;
  origin_location public.inventory_locations;
  destination_location public.inventory_locations;
  line_quantity integer;
  movement_quantity integer;
begin
  select * into v_document
  from public.inventory_documents
  where id = p_document_id and status = 'BORRADOR'
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'DOCUMENT_NOT_DRAFT';
  end if;

  if v_document.origin_location_id is not null then
    select * into origin_location from public.inventory_locations
    where id = v_document.origin_location_id and is_active;
  else
    origin_location := public.default_inventory_location(v_document.origin_warehouse_id);
  end if;
  if v_document.destination_location_id is not null then
    select * into destination_location from public.inventory_locations
    where id = v_document.destination_location_id and is_active;
  else
    destination_location := public.default_inventory_location(v_document.destination_warehouse_id);
  end if;

  -- Validaciones
  if v_document.document_type in ('TRANSFER', 'SALE_DISPATCH', 'SUPPLIER_RETURN', 'CONSIGNMENT')
     and origin_location.id is null then
    raise exception 'No existe una ubicación de origen activa';
  end if;
  if v_document.document_type in ('OPENING', 'ADJUSTMENT', 'TRANSFER', 'PURCHASE_RECEIPT', 'CUSTOMER_RETURN')
     and destination_location.id is null then
    raise exception 'No existe una ubicación de destino activa';
  end if;
  if v_document.document_type = 'TRANSFER' and origin_location.id = destination_location.id then
    raise exception 'El origen y el destino del traslado deben ser diferentes';
  end if;

  -- Confirmar documento
  update public.inventory_documents
     set status = 'CONFIRMED', confirmed_at = now()
   where id = p_document_id
  returning * into v_document;

  -- Crear movimientos de inventario (igual que en create_and_confirm)
  for v_line in select * from public.inventory_document_lines where document_id = p_document_id
  loop
    line_quantity := v_line.quantity;

    if v_document.document_type = 'TRANSFER' then
      -- En borrador -> confirmar: solo crea TRANSFER_OUT y pone DESPACHADA
      -- El TRANSFER_IN se crea en receive_transfer
      insert into public.inventory_transactions (
        product_id, warehouse_id, location_id, command_id, quantity, reason,
        document_id, document_line_id, notes, actor_name,
        device_name, device_identifier
      ) values (
        v_line.product_id,
        origin_location.warehouse_id,
        origin_location.id,
        extensions.gen_random_uuid(),
        -abs(v_line.quantity),
        'TRANSFER_OUT',
        p_document_id, v_line.id, v_document.document_number,
        p_actor_name, p_device_name, p_device_identifier
      );

      -- Poner documento en DESPACHADA para que dispatch_transfer no falle
      -- (el flujo real es: borrador -> confirmar -> despachar -> en tránsito -> recibir)
      update public.inventory_documents
         set status = 'DESPACHADA', confirmed_at = now()
       where id = p_document_id;
    else
      movement_quantity := case v_document.document_type
        when 'SALE_DISPATCH' then -abs(v_line.quantity)
        when 'SUPPLIER_RETURN' then -abs(v_line.quantity)
        when 'CONSIGNMENT' then -abs(v_line.quantity)
        when 'ADJUSTMENT' then v_line.quantity
        else abs(v_line.quantity)
      end;
      insert into public.inventory_transactions (
        product_id, warehouse_id, location_id, command_id, quantity, reason,
        document_id, document_line_id, notes, actor_name,
        device_name, device_identifier
      ) values (
        v_line.product_id,
        case when movement_quantity < 0 then origin_location.warehouse_id
             else destination_location.warehouse_id end,
        case when movement_quantity < 0 then origin_location.id
             else destination_location.id end,
        extensions.gen_random_uuid(),
        movement_quantity,
        case v_document.document_type
          when 'OPENING' then 'INITIAL_STOCK'::public.inventory_transaction_reason
          when 'ADJUSTMENT' then 'ADJUSTMENT'::public.inventory_transaction_reason
          when 'PURCHASE_RECEIPT' then 'PURCHASE'::public.inventory_transaction_reason
          when 'CUSTOMER_RETURN' then 'RETURN'::public.inventory_transaction_reason
          else 'SALE'::public.inventory_transaction_reason
        end,
        p_document_id, v_line.id, v_document.document_number,
        p_actor_name, p_device_name, p_device_identifier
      );
    end if;
  end loop;

    declare
    v_result public.inventory_documents;
  begin
    select * into v_result
    from public.inventory_documents
    where id = p_document_id;
    return v_result;
  end;
end;
$$;

revoke all on function public.confirm_inventory_document(uuid, text, text, text) from public;
grant execute on function public.confirm_inventory_document(uuid, text, text, text) to anon, authenticated;