-- Bloque 1C: Endurecer API de Productos
-- Reemplaza escritura directa sobre tablas por RPCs idempotentes.

-- 1. Extender create_product_with_initial_stock para aceptar todos los campos
--    que actualmente se actualizan en un segundo paso (image_position_x/y,
--    image_scale, catalog_sort_order, packaging_presentation_id).
create or replace function public.create_product_with_initial_stock(
  p_product jsonb,
  p_initial_stock integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.products
language plpgsql security invoker set search_path = '' as $$
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
$$;

revoke all on function public.create_product_with_initial_stock(
  jsonb, integer, text, text, text
) from public;
grant execute on function public.create_product_with_initial_stock(
  jsonb, integer, text, text, text
) to anon, authenticated;

-- 2. RPC create_category
create or replace function public.create_category(
  p_name text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.categories
language plpgsql security invoker set search_path = '' as $$
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
$$;

revoke all on function public.create_category(text, text, text, text) from public;
grant execute on function public.create_category(text, text, text, text)
  to anon, authenticated;

-- 3. RPC update_category
create or replace function public.update_category(
  p_category_id uuid,
  p_name text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.categories
language plpgsql security invoker set search_path = '' as $$
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
$$;

revoke all on function public.update_category(uuid, text, text, text, text)
  from public;
grant execute on function public.update_category(uuid, text, text, text, text)
  to anon, authenticated;

-- 4. RPC update_product
create or replace function public.update_product(
  p_product_id uuid,
  p_product jsonb,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.products
language plpgsql security invoker set search_path = '' as $$
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
$$;

revoke all on function public.update_product(uuid, jsonb, text, text, text)
  from public;
grant execute on function public.update_product(uuid, jsonb, text, text, text)
  to anon, authenticated;

-- 5. RPC deactivate_product
create or replace function public.deactivate_product(
  p_product_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security invoker set search_path = '' as $$
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
$$;

revoke all on function public.deactivate_product(uuid, text, text, text)
  from public;
grant execute on function public.deactivate_product(uuid, text, text, text)
  to anon, authenticated;

-- 6. RPC set_promotion_active
create or replace function public.set_promotion_active(
  p_promotion_id uuid,
  p_is_active boolean,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security invoker set search_path = '' as $$
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
$$;

revoke all on function public.set_promotion_active(uuid, boolean, text, text, text)
  from public;
grant execute on function public.set_promotion_active(uuid, boolean, text, text, text)
  to anon, authenticated;

-- 7. RPC set_promotion_product_condition
create or replace function public.set_promotion_product_condition(
  p_promotion_id uuid,
  p_product_id uuid,
  p_conditions_text text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  insert into public.bulk_promotion_products (
    promotion_id, product_id, conditions_text
  ) values (
    p_promotion_id, p_product_id, btrim(p_conditions_text)
  )
  on conflict (promotion_id, product_id)
  do update set conditions_text = btrim(p_conditions_text);
end;
$$;

revoke all on function public.set_promotion_product_condition(
  uuid, uuid, text, text, text, text
) from public;
grant execute on function public.set_promotion_product_condition(
  uuid, uuid, text, text, text, text
) to anon, authenticated;

-- 8. Revocar escritura directa sobre tablas de productos
revoke insert, update, delete, truncate, references, trigger
  on table public.products
  from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on table public.categories
  from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on table public.bulk_promotions
  from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on table public.bulk_promotion_products
  from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on table public.bulk_promotion_categories
  from anon, authenticated;

-- Mantener SELECT para lecturas
grant select on table public.products to anon, authenticated;
grant select on table public.categories to anon, authenticated;
grant select on table public.bulk_promotions to anon, authenticated;
grant select on table public.bulk_promotion_products to anon, authenticated;
grant select on table public.bulk_promotion_categories to anon, authenticated;

-- 9. Endurecer políticas de Storage para product-images
drop policy if exists product_images_local_insert on storage.objects;
drop policy if exists product_images_local_update on storage.objects;
drop policy if exists product_images_local_delete on storage.objects;

create policy product_images_insert on storage.objects
  for insert to anon, authenticated
  with check (
    bucket_id = 'product-images'
    and name ~ '^[A-Za-z0-9._-]+\.(jpg|jpeg|png|webp)$'
  );

create policy product_images_update on storage.objects
  for update to anon, authenticated
  using (
    bucket_id = 'product-images'
    and name ~ '^[A-Za-z0-9._-]+\.(jpg|jpeg|png|webp)$'
  )
  with check (
    bucket_id = 'product-images'
    and name ~ '^[A-Za-z0-9._-]+\.(jpg|jpeg|png|webp)$'
  );

create policy product_images_delete on storage.objects
  for delete to anon, authenticated
  using (
    bucket_id = 'product-images'
    and name ~ '^[A-Za-z0-9._-]+\.(jpg|jpeg|png|webp)$'
  );
