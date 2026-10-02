-- Persistir la URL de imagen en crear/actualizar producto
--
-- La app sube la foto a storage y envía image_url en p_product, pero
-- ningún RPC la guardaba: la URL se perdía y la imagen nunca aparecía.
-- Se añade la columna a ambas sentencias.

CREATE OR REPLACE FUNCTION public.create_product_with_initial_stock(p_product jsonb, p_initial_stock integer, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS products
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_row public.products%rowtype;
begin
  insert into public.products (
    sku, barcode, name, description, category_id,
    unit_price, package_price, min_order_quantity, minimum_sale_quantity,
    packaging_presentation_id, cbm_per_moq, factory_cost,
    image_position_x, image_position_y, image_scale, image_url,
    catalog_sort_order, reorder_point, extra_costs,
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
    p_product->>'image_url',
    (p_product->>'catalog_sort_order')::integer,
    (p_product->>'reorder_point')::integer,
    coalesce((p_product->>'extra_costs')::numeric, 0),
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

  select * into v_row from public.products where id = v_id;
  return v_row;
end;
$function$;

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
         image_url = coalesce(p_product->>'image_url', image_url),
         catalog_sort_order = coalesce((p_product->>'catalog_sort_order')::integer, catalog_sort_order),
         reorder_point = coalesce((p_product->>'reorder_point')::integer, reorder_point),
         extra_costs = coalesce((p_product->>'extra_costs')::numeric, extra_costs),
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
