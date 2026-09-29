do $$
declare
  fallback_presentation_id uuid;
begin
  insert into public.packaging_presentations (name, sort_order)
  select 'Unidad', 0
  where not exists (select 1 from public.packaging_presentations);

  select id into fallback_presentation_id
  from public.packaging_presentations
  where is_active
  order by sort_order, name
  limit 1;

  update public.products p
  set packaging_presentation_id = coalesce(
    (
      select pp.id
      from public.packaging_presentations pp
      join public.app_settings settings on settings.id = true
      where lower(pp.name) = lower(
        case p.packaging_type
          when 'UNIT' then settings.packaging_unit_label
          when 'BOX' then settings.packaging_box_label
          when 'SET' then settings.packaging_set_label
        end
      )
      limit 1
    ),
    fallback_presentation_id
  )
  where p.packaging_presentation_id is null;

  if exists (
    select 1 from public.products where packaging_presentation_id is null
  ) then
    raise exception 'No fue posible asignar una presentación a todos los productos';
  end if;
end;
$$;

alter table public.products
  alter column packaging_presentation_id set not null;

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
begin
  if not exists (
    select 1 from public.packaging_presentations pp
    where pp.id = (p_product ->> 'packaging_presentation_id')::uuid
      and pp.is_active
  ) then
    raise exception 'La presentación seleccionada no existe o está inactiva';
  end if;

  insert into public.products (
    id, sku, barcode, name, description, category_id, currency_code,
    unit_price, package_price, min_order_quantity, minimum_sale_quantity,
    packaging_presentation_id, cbm_per_moq, factory_cost, image_url,
    reorder_point, promo_price, promo_text, is_active, created_by,
    created_device_name, created_device_identifier
  ) values (
    (p_product ->> 'id')::uuid,
    p_product ->> 'sku', nullif(p_product ->> 'barcode', ''),
    p_product ->> 'name', coalesce(p_product ->> 'description', ''),
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
    insert into public.inventory_transactions (
      product_id, quantity, reason, notes, actor_name,
      device_name, device_identifier
    ) values (
      created_product.id, p_initial_stock, 'INITIAL_STOCK',
      'Stock inicial registrado al crear el producto', p_actor_name,
      p_device_name, p_device_identifier
    );
    select * into created_product
    from public.products where id = created_product.id;
  end if;

  return created_product;
end;
$$;
