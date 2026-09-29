do $$
declare
  movement public.inventory_transactions;
  created_document public.inventory_documents;
  created_line public.inventory_document_lines;
  mapped_type public.inventory_document_type;
begin
  alter table public.inventory_transactions
    disable trigger inventory_transactions_no_update_or_delete;

  for movement in
    select * from public.inventory_transactions
    where document_id is null
    order by created_at
  loop
    mapped_type := case movement.reason
      when 'INITIAL_STOCK' then 'OPENING'::public.inventory_document_type
      when 'PURCHASE' then 'PURCHASE_RECEIPT'::public.inventory_document_type
      when 'SALE' then 'SALE_DISPATCH'::public.inventory_document_type
      when 'RETURN' then 'CUSTOMER_RETURN'::public.inventory_document_type
      else 'ADJUSTMENT'::public.inventory_document_type
    end;

    insert into public.inventory_documents (
      command_id, document_number, document_type, status,
      origin_warehouse_id, origin_location_id,
      destination_warehouse_id, destination_location_id,
      notes, confirmed_at, created_at,
      created_by, created_device_name, created_device_identifier
    ) values (
      movement.command_id,
      public.inventory_document_prefix(mapped_type) || '-' ||
        lpad(nextval('public.inventory_document_number_seq')::text, 8, '0'),
      mapped_type, 'CONFIRMED',
      case when movement.quantity < 0 then movement.warehouse_id end,
      case when movement.quantity < 0 then movement.location_id end,
      case when movement.quantity > 0 then movement.warehouse_id end,
      case when movement.quantity > 0 then movement.location_id end,
      coalesce(movement.notes, 'Movimiento anterior migrado'),
      movement.created_at, movement.created_at,
      movement.actor_name, movement.device_name, movement.device_identifier
    ) returning * into created_document;

    insert into public.inventory_document_lines (
      document_id, product_id, quantity, notes, created_at
    ) values (
      created_document.id, movement.product_id, movement.quantity,
      movement.notes, movement.created_at
    ) returning * into created_line;

    update public.inventory_transactions
    set document_id = created_document.id,
        document_line_id = created_line.id
    where id = movement.id;
  end loop;

  alter table public.inventory_transactions
    enable trigger inventory_transactions_no_update_or_delete;
end;
$$;

create or replace function public.create_product_with_initial_stock(
  p_product jsonb,
  p_initial_stock integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
)
returns public.products
language plpgsql
security invoker
set search_path = ''
as $$
declare
  created_product public.products;
  default_warehouse_id uuid;
begin
  if not exists (
    select 1 from public.packaging_presentations pp
    where pp.id = (p_product ->> 'packaging_presentation_id')::uuid
      and pp.is_active
  ) then
    raise exception 'La presentación seleccionada no existe o está inactiva';
  end if;

  select id into default_warehouse_id
  from public.warehouses where is_default and is_active limit 1;
  if default_warehouse_id is null then
    raise exception 'No existe una bodega predeterminada activa';
  end if;

  insert into public.products (
    id, sku, barcode, name, description, category_id, currency_code,
    unit_price, package_price, min_order_quantity, minimum_sale_quantity,
    packaging_presentation_id, cbm_per_moq, factory_cost, image_url,
    reorder_point, promo_price, promo_text, is_active, created_by,
    created_device_name, created_device_identifier
  ) values (
    (p_product ->> 'id')::uuid, p_product ->> 'sku',
    nullif(p_product ->> 'barcode', ''), p_product ->> 'name',
    coalesce(p_product ->> 'description', ''),
    (p_product ->> 'category_id')::uuid,
    coalesce(p_product ->> 'currency_code', 'USD'),
    (p_product ->> 'unit_price')::numeric,
    nullif(p_product ->> 'package_price', '')::numeric,
    (p_product ->> 'min_order_quantity')::integer,
    coalesce((p_product ->> 'minimum_sale_quantity')::integer, 1),
    (p_product ->> 'packaging_presentation_id')::uuid,
    (p_product ->> 'cbm_per_moq')::numeric,
    (p_product ->> 'factory_cost')::numeric,
    nullif(p_product ->> 'image_url', ''),
    (p_product ->> 'reorder_point')::integer,
    nullif(p_product ->> 'promo_price', '')::numeric,
    nullif(p_product ->> 'promo_text', ''),
    coalesce((p_product ->> 'is_active')::boolean, true),
    p_actor_name, p_device_name, p_device_identifier
  ) returning * into created_product;

  if p_initial_stock <> 0 then
    perform public.create_and_confirm_inventory_document(
      gen_random_uuid(), 'OPENING',
      jsonb_build_array(jsonb_build_object(
        'product_id', created_product.id,
        'quantity', p_initial_stock,
        'notes', 'Stock inicial registrado al crear el producto'
      )),
      null, null, default_warehouse_id, null,
      created_product.sku, 'Apertura automática de inventario',
      p_actor_name, p_device_name, p_device_identifier
    );
    select * into created_product from public.products
    where id = created_product.id;
  end if;

  return created_product;
end;
$$;
