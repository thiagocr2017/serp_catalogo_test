-- Conversión de RPCs de escritura a SECURITY DEFINER
--
-- Las migraciones de endurecimiento de producto e inventario declararon
-- estos RPC como SECURITY INVOKER y, en la misma serie, revocaron
-- INSERT/UPDATE/DELETE sobre sus tablas a anon y authenticated. Un RPC
-- invoker ejecuta con los permisos del llamador, por lo que toda
-- escritura fallaba con 42501 ("permission denied for table ...").
--
-- Se convierten a SECURITY DEFINER con search_path = '', el patrón que
-- ya usan los RPC de configuración, pagos y ventas. Los permisos de
-- tablas se mantienen revocados: la escritura queda únicamente en la
-- superficie de las RPC.

CREATE OR REPLACE FUNCTION public.confirm_count_and_adjust(p_count_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_line public.inventory_count_lines%rowtype;
  v_location_id uuid;
begin
  update public.inventory_counts set status = 'CONFIRMED', confirmed_at = now()
  where id = p_count_id and status = 'REVIEW';

  if not found then
    raise exception using errcode = 'P0001', message = 'COUNT_NOT_REVIEWABLE';
  end if;

  for v_line in
    select * from public.inventory_count_lines
    where count_id = p_count_id and difference <> 0 and reviewed
  loop
    select id into v_location_id from public.inventory_locations
    where warehouse_id = (select warehouse_id from public.inventory_counts where id = p_count_id)
      and is_default limit 1;

    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier
    ) values (
      v_line.product_id,
      (select warehouse_id from public.inventory_counts where id = p_count_id),
      coalesce(v_line.location_id, v_location_id),
      extensions.gen_random_uuid(),
      v_line.difference,
      'ADJUSTMENT',
      p_actor_name, p_device_name, p_device_identifier
    );
  end loop;
end;
$function$;

revoke all on function public.confirm_count_and_adjust(uuid, text, text, text) from public;
grant execute on function public.confirm_count_and_adjust(uuid, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.consume_reservation(p_reservation_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_reservation public.inventory_reservations%rowtype;
begin
  select * into v_reservation from public.inventory_reservations
  where id = p_reservation_id and status = 'PENDING' for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'RESERVATION_NOT_FOUND';
  end if;

  update public.inventory_reservations
  set status = 'CONSUMED'
  where id = p_reservation_id;

  update public.inventory_balances
  set reserved_quantity = reserved_quantity - v_reservation.quantity,
      quantity = quantity - v_reservation.quantity
  where product_id = v_reservation.product_id and location_id = v_reservation.location_id;

  update public.products
  set current_stock = current_stock - v_reservation.quantity
  where id = v_reservation.product_id;
end;
$function$;

revoke all on function public.consume_reservation(uuid, text, text, text) from public;
grant execute on function public.consume_reservation(uuid, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_and_confirm_inventory_document(p_command_id uuid, p_document_type inventory_document_type, p_lines jsonb, p_origin_warehouse_id uuid, p_origin_location_id uuid, p_destination_warehouse_id uuid, p_destination_location_id uuid, p_external_reference text, p_notes text, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS inventory_documents
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  existing_document public.inventory_documents;
  created_document public.inventory_documents;
  created_line public.inventory_document_lines;
  origin_location public.inventory_locations;
  destination_location public.inventory_locations;
  line jsonb;
  line_quantity integer;
  movement_quantity integer;
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
    p_document_type, 'CONFIRMED',
    origin_location.warehouse_id, origin_location.id,
    destination_location.warehouse_id, destination_location.id,
    nullif(trim(p_external_reference), ''), nullif(trim(p_notes), ''), now(),
    p_actor_name, p_device_name, p_device_identifier
  ) returning * into created_document;

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

    if p_document_type = 'TRANSFER' then
      insert into public.inventory_transactions (
        product_id, warehouse_id, location_id, command_id, quantity, reason,
        document_id, document_line_id, notes, actor_name,
        device_name, device_identifier
      ) values (
        created_line.product_id, origin_location.warehouse_id,
        origin_location.id, gen_random_uuid(), -abs(line_quantity),
        'TRANSFER_OUT', created_document.id, created_line.id,
        created_document.document_number, p_actor_name,
        p_device_name, p_device_identifier
      );
      insert into public.inventory_transactions (
        product_id, warehouse_id, location_id, command_id, quantity, reason,
        document_id, document_line_id, notes, actor_name,
        device_name, device_identifier
      ) values (
        created_line.product_id, destination_location.warehouse_id,
        destination_location.id, gen_random_uuid(), abs(line_quantity),
        'TRANSFER_IN', created_document.id, created_line.id,
        created_document.document_number, p_actor_name,
        p_device_name, p_device_identifier
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
        created_line.product_id,
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

  return created_document;
end;
$function$;

revoke all on function public.create_and_confirm_inventory_document(uuid, inventory_document_type, jsonb, uuid, uuid, uuid, uuid, text, text, text, text, text) from public;
grant execute on function public.create_and_confirm_inventory_document(uuid, inventory_document_type, jsonb, uuid, uuid, uuid, uuid, text, text, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_category(p_name text, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS categories
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.categories (
    name, created_by, created_device_name, created_device_identifier
  ) values (
    btrim(p_name), p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_id;
  return (select * from public.categories where id = v_id);
end;
$function$;

revoke all on function public.create_category(text, text, text, text) from public;
grant execute on function public.create_category(text, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_inventory_count(p_warehouse_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS inventory_counts
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
begin
  insert into public.inventory_counts (warehouse_id, status, created_by, created_device_name, created_device_identifier)
  values (p_warehouse_id, 'DRAFT', p_actor_name, p_device_name, p_device_identifier)
  returning id into v_id;
  return (select * from public.inventory_counts where id = v_id);
end;
$function$;

revoke all on function public.create_inventory_count(uuid, text, text, text) from public;
grant execute on function public.create_inventory_count(uuid, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_inventory_location(p_warehouse_id uuid, p_code text, p_name text, p_is_default boolean, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS inventory_locations
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
begin
  if btrim(p_code) = '' or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if not exists (
    select 1 from public.warehouses
    where id = p_warehouse_id and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'WAREHOUSE_NOT_FOUND';
  end if;
  if exists (
    select 1 from public.inventory_locations
    where warehouse_id = p_warehouse_id and code = btrim(p_code) and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_LOCATION_CODE';
  end if;
  if p_is_default then
    update public.inventory_locations set is_default = false
    where warehouse_id = p_warehouse_id and is_active;
  end if;
  insert into public.inventory_locations (
    warehouse_id, code, name, is_default,
    created_by, created_device_name, created_device_identifier
  ) values (
    p_warehouse_id, btrim(p_code), btrim(p_name), p_is_default,
    p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_id;
  return (select * from public.inventory_locations where id = v_id);
end;
$function$;

revoke all on function public.create_inventory_location(uuid, text, text, boolean, text, text, text) from public;
grant execute on function public.create_inventory_location(uuid, text, text, boolean, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_product_with_initial_stock(p_product jsonb, p_initial_stock integer, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS products
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
begin
  insert into public.products (
    sku, barcode, name, description, category_id,
    unit_price, package_price, min_order_quantity, minimum_sale_quantity,
    packaging_presentation_id, cbm_per_moq, factory_cost,
    image_position_x, image_position_y, image_scale,
    catalog_sort_order, reorder_point,
    created_by, created_device_name, created_device_identifier
  ) values (
    p_product->>'sku',
    p_product->>'barcode',
    p_product->>'name',
    p_product->>'description',
    (p_product->>'category_id')::uuid,
    (p_product->>'unit_price')::numeric,
    (p_product->>'package_price')::numeric,
    (p_product->>'min_order_quantity')::integer,
    (p_product->>'minimum_sale_quantity')::integer,
    (p_product->>'packaging_presentation_id')::uuid,
    (p_product->>'cbm_per_moq')::numeric,
    (p_product->>'factory_cost')::numeric,
    (p_product->>'image_position_x')::numeric,
    (p_product->>'image_position_y')::numeric,
    (p_product->>'image_scale')::numeric,
    (p_product->>'catalog_sort_order')::integer,
    (p_product->>'reorder_point')::integer,
    p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_id;

  if p_initial_stock is not null and p_initial_stock <> 0 then
    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier
    )
    select v_id, w.id, l.id, extensions.gen_random_uuid(), p_initial_stock, 'INITIAL_STOCK',
           p_actor_name, p_device_name, p_device_identifier
    from public.warehouses w, public.inventory_locations l
    where w.is_default = true and l.is_default = true
    limit 1;
  end if;

  return (select * from public.products where id = v_id);
end;
$function$;

revoke all on function public.create_product_with_initial_stock(jsonb, integer, text, text, text) from public;
grant execute on function public.create_product_with_initial_stock(jsonb, integer, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_warehouse(p_code text, p_name text, p_is_default boolean, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS warehouses
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
begin
  if btrim(p_code) = '' or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if exists (
    select 1 from public.warehouses
    where code = btrim(p_code) and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_WAREHOUSE_CODE';
  end if;
  if p_is_default then
    update public.warehouses set is_default = false where is_active;
  end if;
  insert into public.warehouses (
    code, name, is_default,
    created_by, created_device_name, created_device_identifier
  ) values (
    btrim(p_code), btrim(p_name), p_is_default,
    p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_id;
  return (select * from public.warehouses where id = v_id);
end;
$function$;

revoke all on function public.create_warehouse(text, text, boolean, text, text, text) from public;
grant execute on function public.create_warehouse(text, text, boolean, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.deactivate_product(p_product_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  update public.products
     set is_active = false,
         deleted_at = now(),
         deleted_by = p_actor_name,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_product_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
end;
$function$;

revoke all on function public.deactivate_product(uuid, text, text, text) from public;
grant execute on function public.deactivate_product(uuid, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.dispatch_transfer(p_document_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  update public.inventory_documents set status = 'DESPACHADA'
  where id = p_document_id and status = 'BORRADOR';
  if not found then
    raise exception using errcode = 'P0001', message = 'TRANSFER_NOT_DRAFT';
  end if;
end;
$function$;

revoke all on function public.dispatch_transfer(uuid, text, text, text) from public;
grant execute on function public.dispatch_transfer(uuid, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.mark_transfer_in_transit(p_document_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  update public.inventory_documents set status = 'EN_TRANSITO'
  where id = p_document_id and status = 'DESPACHADA';
  if not found then
    raise exception using errcode = 'P0001', message = 'TRANSFER_NOT_DISPATCHED';
  end if;
end;
$function$;

revoke all on function public.mark_transfer_in_transit(uuid, text, text, text) from public;
grant execute on function public.mark_transfer_in_transit(uuid, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.receive_transfer(p_document_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_line public.inventory_document_lines%rowtype;
begin
  update public.inventory_documents set status = 'RECIBIDA'
  where id = p_document_id and status = 'EN_TRANSITO';
  if not found then
    raise exception using errcode = 'P0001', message = 'TRANSFER_NOT_IN_TRANSIT';
  end if;

  for v_line in
    select * from public.inventory_document_lines where document_id = p_document_id
  loop
    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier, document_id
    ) values (
      v_line.product_id,
      (select destination_warehouse_id from public.inventory_documents where id = p_document_id),
      (select destination_location_id from public.inventory_documents where id = p_document_id),
      extensions.gen_random_uuid(),
      v_line.quantity,
      'TRANSFER_IN',
      p_actor_name, p_device_name, p_device_identifier,
      p_document_id
    );
  end loop;
end;
$function$;

revoke all on function public.receive_transfer(uuid, text, text, text) from public;
grant execute on function public.receive_transfer(uuid, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.record_inventory_transaction(p_command_id uuid, p_product_id uuid, p_location_id uuid, p_quantity integer, p_reason inventory_transaction_reason, p_notes text, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS inventory_transactions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  existing_transaction public.inventory_transactions;
  selected_warehouse_id uuid;
  created_transaction public.inventory_transactions;
begin
  select * into existing_transaction
  from public.inventory_transactions
  where command_id = p_command_id;

  if found then
    return existing_transaction;
  end if;

  if p_quantity = 0 then
    raise exception 'La cantidad debe ser distinta de cero';
  end if;

  if p_reason in ('SALE', 'REVERSAL') and p_quantity > 0
     or p_reason in ('PURCHASE', 'RETURN', 'INITIAL_STOCK') and p_quantity < 0 then
    raise exception 'El signo de la cantidad no coincide con el motivo';
  end if;

  select warehouse_id into selected_warehouse_id
  from public.inventory_locations
  where id = p_location_id and is_active;

  if selected_warehouse_id is null then
    raise exception 'La ubicación seleccionada no existe o está inactiva';
  end if;

  insert into public.inventory_transactions (
    product_id, warehouse_id, location_id, command_id, quantity, reason,
    notes, actor_name, device_name, device_identifier
  ) values (
    p_product_id, selected_warehouse_id, p_location_id, p_command_id,
    p_quantity, p_reason, nullif(trim(p_notes), ''), p_actor_name,
    p_device_name, p_device_identifier
  ) returning * into created_transaction;

  return created_transaction;
end;
$function$;

revoke all on function public.record_inventory_transaction(uuid, uuid, uuid, integer, inventory_transaction_reason, text, text, text, text) from public;
grant execute on function public.record_inventory_transaction(uuid, uuid, uuid, integer, inventory_transaction_reason, text, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.release_reservation(p_reservation_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_reservation public.inventory_reservations%rowtype;
begin
  select * into v_reservation from public.inventory_reservations
  where id = p_reservation_id and status = 'PENDING' for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'RESERVATION_NOT_FOUND';
  end if;

  update public.inventory_reservations
  set status = 'RELEASED', released_at = now()
  where id = p_reservation_id;

  update public.inventory_balances
  set reserved_quantity = reserved_quantity - v_reservation.quantity
  where product_id = v_reservation.product_id and location_id = v_reservation.location_id;
end;
$function$;

revoke all on function public.release_reservation(uuid, text, text, text) from public;
grant execute on function public.release_reservation(uuid, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.reserve_inventory(p_command_id uuid, p_product_id uuid, p_location_id uuid, p_order_id text, p_quantity integer, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS inventory_reservations
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_reservation public.inventory_reservations%rowtype;
  v_available integer;
begin
  if p_quantity <= 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  select quantity - reserved_quantity into v_available
  from public.inventory_balances
  where product_id = p_product_id and location_id = p_location_id
  for update;

  if v_available is null or v_available < p_quantity then
    raise exception using errcode = 'P0001', message = 'INSUFFICIENT_STOCK';
  end if;

  insert into public.inventory_reservations (
    product_id, location_id, order_id, quantity, command_id,
    created_by, created_device_name, created_device_identifier
  ) values (
    p_product_id, p_location_id, p_order_id, p_quantity, p_command_id,
    p_actor_name, p_device_name, p_device_identifier
  ) on conflict (command_id) do nothing
  returning * into v_reservation;

  if not found then
    select * into v_reservation from public.inventory_reservations where command_id = p_command_id;
    return v_reservation;
  end if;

  update public.inventory_balances
  set reserved_quantity = reserved_quantity + p_quantity
  where product_id = p_product_id and location_id = p_location_id;

  return v_reservation;
end;
$function$;

revoke all on function public.reserve_inventory(uuid, uuid, uuid, text, integer, text, text, text) from public;
grant execute on function public.reserve_inventory(uuid, uuid, uuid, text, integer, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.reverse_inventory_transaction(p_command_id uuid, p_original_transaction_id uuid, p_notes text, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS inventory_transactions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  existing_transaction public.inventory_transactions;
  original_transaction public.inventory_transactions;
  created_transaction public.inventory_transactions;
begin
  select * into existing_transaction
  from public.inventory_transactions
  where command_id = p_command_id;
  if found then return existing_transaction; end if;

  select * into original_transaction
  from public.inventory_transactions
  where id = p_original_transaction_id;

  if not found then raise exception 'El movimiento original no existe'; end if;
  if original_transaction.reason = 'REVERSAL' then
    raise exception 'Una reversión no puede revertirse directamente';
  end if;
  if nullif(trim(p_notes), '') is null then
    raise exception 'El motivo de la reversión es obligatorio';
  end if;

  insert into public.inventory_transactions (
    product_id, warehouse_id, location_id, command_id, quantity, reason,
    reversal_of_transaction_id, notes, actor_name, device_name,
    device_identifier
  ) values (
    original_transaction.product_id, original_transaction.warehouse_id,
    original_transaction.location_id, p_command_id,
    -original_transaction.quantity, 'REVERSAL', original_transaction.id,
    trim(p_notes), p_actor_name, p_device_name, p_device_identifier
  ) returning * into created_transaction;

  return created_transaction;
end;
$function$;

revoke all on function public.reverse_inventory_transaction(uuid, uuid, text, text, text, text) from public;
grant execute on function public.reverse_inventory_transaction(uuid, uuid, text, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.save_bulk_promotion(p_promotion jsonb, p_product_ids uuid[], p_category_ids uuid[], p_product_conditions jsonb, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS bulk_promotions
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_promotion_id uuid := (p_promotion ->> 'id')::uuid;
  v_applies_to_all boolean := coalesce(
    (p_promotion ->> 'applies_to_all_products')::boolean,
    false
  );
  v_saved public.bulk_promotions;
  v_condition record;
  v_condition_product_id uuid;
  v_linked_product_ids uuid[] := coalesce(p_product_ids, array[]::uuid[]);
begin
  if nullif(trim(p_promotion ->> 'name'), '') is null then
    raise exception 'El nombre de la promoción es obligatorio';
  end if;

  if (p_promotion ->> 'discount_percentage')::numeric <= 0
    or (p_promotion ->> 'discount_percentage')::numeric > 100 then
    raise exception 'El descuento debe ser mayor que 0 y máximo 100';
  end if;

  if (p_promotion ->> 'end_date')::timestamptz <= now() then
    raise exception 'La fecha final debe ser posterior al momento actual';
  end if;

  if not v_applies_to_all
    and cardinality(coalesce(p_category_ids, array[]::uuid[])) = 0
    and cardinality(coalesce(p_product_ids, array[]::uuid[])) = 0 then
    raise exception 'Seleccione al menos un producto o una categoría';
  end if;

  if exists (
    select 1 from unnest(coalesce(p_category_ids, array[]::uuid[])) selected_id
    where not exists (
      select 1 from public.categories c
      where c.id = selected_id and c.is_active
    )
  ) then
    raise exception 'Una o más categorías no existen o están inactivas';
  end if;

  if exists (
    select 1 from unnest(coalesce(p_product_ids, array[]::uuid[])) selected_id
    where not exists (
      select 1 from public.products p
      where p.id = selected_id and p.is_active
    )
  ) then
    raise exception 'Uno o más productos no existen o están inactivos';
  end if;

  for v_condition in
    select key, value
    from jsonb_each_text(coalesce(p_product_conditions, '{}'::jsonb))
  loop
    v_condition_product_id := v_condition.key::uuid;
    if not exists (
      select 1
      from public.products p
      where p.id = v_condition_product_id
        and p.is_active
        and (
          v_applies_to_all
          or p.id = any(coalesce(p_product_ids, array[]::uuid[]))
          or p.category_id = any(coalesce(p_category_ids, array[]::uuid[]))
        )
    ) then
      raise exception 'La condición individual contiene un producto fuera del alcance';
    end if;
    if not (v_condition_product_id = any(v_linked_product_ids)) then
      v_linked_product_ids := array_append(
        v_linked_product_ids,
        v_condition_product_id
      );
    end if;
  end loop;

  if exists (
    select 1 from public.bulk_promotions bp where bp.id = v_promotion_id
  ) then
    update public.bulk_promotions bp
    set name = trim(p_promotion ->> 'name'),
        discount_percentage = (p_promotion ->> 'discount_percentage')::numeric,
        conditions_text = coalesce(p_promotion ->> 'conditions_text', ''),
        badge_image_url = nullif(p_promotion ->> 'badge_image_url', ''),
        start_date = nullif(p_promotion ->> 'start_date', '')::timestamptz,
        end_date = (p_promotion ->> 'end_date')::timestamptz,
        applies_to_all_products = v_applies_to_all,
        is_active = coalesce((p_promotion ->> 'is_active')::boolean, true),
        updated_by = p_actor_name,
        updated_device_name = p_device_name,
        updated_device_identifier = p_device_identifier
    where bp.id = v_promotion_id
    returning bp.* into v_saved;

    delete from public.bulk_promotion_products bpp
    where bpp.promotion_id = v_promotion_id;
    delete from public.bulk_promotion_categories bpc
    where bpc.promotion_id = v_promotion_id;
  else
    insert into public.bulk_promotions (
      id, name, discount_percentage, conditions_text, badge_image_url,
      start_date, end_date, applies_to_all_products, is_active,
      created_by, created_device_name, created_device_identifier
    ) values (
      v_promotion_id,
      trim(p_promotion ->> 'name'),
      (p_promotion ->> 'discount_percentage')::numeric,
      coalesce(p_promotion ->> 'conditions_text', ''),
      nullif(p_promotion ->> 'badge_image_url', ''),
      nullif(p_promotion ->> 'start_date', '')::timestamptz,
      (p_promotion ->> 'end_date')::timestamptz,
      v_applies_to_all,
      coalesce((p_promotion ->> 'is_active')::boolean, true),
      p_actor_name,
      p_device_name,
      p_device_identifier
    ) returning * into v_saved;
  end if;

  insert into public.bulk_promotion_products (
    promotion_id, product_id, conditions_text
  )
  select
    v_promotion_id,
    selected_product_id,
    coalesce(p_product_conditions ->> selected_product_id::text, '')
  from unnest(v_linked_product_ids) selected_product_id
  on conflict (promotion_id, product_id) do update
  set conditions_text = excluded.conditions_text;

  insert into public.bulk_promotion_categories (promotion_id, category_id)
  select v_promotion_id, selected_category_id
  from unnest(coalesce(p_category_ids, array[]::uuid[])) selected_category_id
  on conflict do nothing;

  return v_saved;
end;
$function$;

revoke all on function public.save_bulk_promotion(jsonb, uuid[], uuid[], jsonb, text, text, text) from public;
grant execute on function public.save_bulk_promotion(jsonb, uuid[], uuid[], jsonb, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.set_promotion_active(p_promotion_id uuid, p_is_active boolean, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  update public.bulk_promotions
     set is_active = p_is_active,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_promotion_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
end;
$function$;

revoke all on function public.set_promotion_active(uuid, boolean, text, text, text) from public;
grant execute on function public.set_promotion_active(uuid, boolean, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.set_promotion_product_condition(p_promotion_id uuid, p_product_id uuid, p_conditions_text text, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  insert into public.bulk_promotion_products (
    promotion_id, product_id, conditions_text
  ) values (
    p_promotion_id, p_product_id, btrim(p_conditions_text)
  )
  on conflict (promotion_id, product_id)
  do update set conditions_text = btrim(p_conditions_text);
end;
$function$;

revoke all on function public.set_promotion_product_condition(uuid, uuid, text, text, text, text) from public;
grant execute on function public.set_promotion_product_condition(uuid, uuid, text, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.update_category(p_category_id uuid, p_name text, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS categories
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v public.categories%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  update public.categories
     set name = btrim(p_name),
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_category_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$function$;

revoke all on function public.update_category(uuid, text, text, text, text) from public;
grant execute on function public.update_category(uuid, text, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.update_inventory_location(p_location_id uuid, p_code text, p_name text, p_is_default boolean, p_is_active boolean, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS inventory_locations
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v public.inventory_locations%rowtype;
begin
  if btrim(p_code) = '' or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if exists (
    select 1 from public.inventory_locations
    where warehouse_id = (select warehouse_id from public.inventory_locations where id = p_location_id)
      and code = btrim(p_code) and is_active and id <> p_location_id
  ) then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_LOCATION_CODE';
  end if;
  if p_is_default then
    update public.inventory_locations set is_default = false
    where warehouse_id = (select warehouse_id from public.inventory_locations where id = p_location_id)
      and is_active and id <> p_location_id;
  end if;
  update public.inventory_locations
     set code = btrim(p_code),
         name = btrim(p_name),
         is_default = p_is_default,
         is_active = p_is_active,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_location_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$function$;

revoke all on function public.update_inventory_location(uuid, text, text, boolean, boolean, text, text, text) from public;
grant execute on function public.update_inventory_location(uuid, text, text, boolean, boolean, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.update_product(p_product_id uuid, p_product jsonb, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS products
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v public.products%rowtype;
begin
  update public.products
     set sku = coalesce(p_product->>'sku', sku),
         barcode = coalesce(p_product->>'barcode', barcode),
         name = coalesce(p_product->>'name', name),
         description = coalesce(p_product->>'description', description),
         category_id = coalesce((p_product->>'category_id')::uuid, category_id),
         unit_price = coalesce((p_product->>'unit_price')::numeric, unit_price),
         package_price = coalesce((p_product->>'package_price')::numeric, package_price),
         min_order_quantity = coalesce((p_product->>'min_order_quantity')::integer, min_order_quantity),
         minimum_sale_quantity = coalesce((p_product->>'minimum_sale_quantity')::integer, minimum_sale_quantity),
         packaging_presentation_id = coalesce((p_product->>'packaging_presentation_id')::uuid, packaging_presentation_id),
         cbm_per_moq = coalesce((p_product->>'cbm_per_moq')::numeric, cbm_per_moq),
         factory_cost = coalesce((p_product->>'factory_cost')::numeric, factory_cost),
         image_position_x = coalesce((p_product->>'image_position_x')::numeric, image_position_x),
         image_position_y = coalesce((p_product->>'image_position_y')::numeric, image_position_y),
         image_scale = coalesce((p_product->>'image_scale')::numeric, image_scale),
         catalog_sort_order = coalesce((p_product->>'catalog_sort_order')::integer, catalog_sort_order),
         reorder_point = coalesce((p_product->>'reorder_point')::integer, reorder_point),
         promo_price = coalesce((p_product->>'promo_price')::numeric, promo_price),
         promo_text = coalesce(p_product->>'promo_text', promo_text),
         is_active = coalesce((p_product->>'is_active')::boolean, is_active),
         deleted_at = case when p_product->>'is_active' = 'true' then null else deleted_at end,
         deleted_by = case when p_product->>'is_active' = 'true' then null else deleted_by end,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_product_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$function$;

revoke all on function public.update_product(uuid, jsonb, text, text, text) from public;
grant execute on function public.update_product(uuid, jsonb, text, text, text) to anon, authenticated;

CREATE OR REPLACE FUNCTION public.update_warehouse(p_warehouse_id uuid, p_code text, p_name text, p_is_default boolean, p_is_active boolean, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS warehouses
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v public.warehouses%rowtype;
begin
  if btrim(p_code) = '' or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if exists (
    select 1 from public.warehouses
    where code = btrim(p_code) and is_active and id <> p_warehouse_id
  ) then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_WAREHOUSE_CODE';
  end if;
  if p_is_default then
    update public.warehouses set is_default = false
    where is_active and id <> p_warehouse_id;
  end if;
  update public.warehouses
     set code = btrim(p_code),
         name = btrim(p_name),
         is_default = p_is_default,
         is_active = p_is_active,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_warehouse_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$function$;

revoke all on function public.update_warehouse(uuid, text, text, boolean, boolean, text, text, text) from public;
grant execute on function public.update_warehouse(uuid, text, text, boolean, boolean, text, text, text) to anon, authenticated;
