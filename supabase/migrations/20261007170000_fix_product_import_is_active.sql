-- Migration: fix_product_import_is_active
-- Modificar create_product_with_initial_stock para que procese is_active correctamente.
-- Incluye validación robusta y valores booleanos al insertarlo.

create or replace function public.create_product_with_initial_stock(
  p_product jsonb,
  p_initial_stock integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
)
returns public.products
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product public.products;
  v_category_id uuid;
  v_stock_document_id uuid;
  v_units_per_presentation numeric(10,3);
  v_is_active boolean;
begin
  if (p_product->>'units_per_presentation') is not null then
    v_units_per_presentation := (p_product->>'units_per_presentation')::numeric(10,3);
    if v_units_per_presentation <= 0 then
      raise exception 'units_per_presentation must be greater than 0';
    end if;
  else
    v_units_per_presentation := 1.0;
  end if;

  v_is_active := coalesce((p_product->>'is_active')::boolean, true);

  if p_product->>'category_id' is not null then
    v_category_id := (p_product->>'category_id')::uuid;
  else
    select id into v_category_id from public.categories where name = 'Sin Categoria' limit 1;
    if v_category_id is null then
      insert into public.categories (name, created_by, created_device_name, created_device_identifier)
      values ('Sin Categoria', p_actor_name, p_device_name, p_device_identifier)
      returning id into v_category_id;
    end if;
  end if;

  insert into public.products (
    sku, barcode, name, description, category_id, base_price,
    minimum_stock_level, maximum_stock_level, presentation_unit,
    units_per_presentation, image_url, extra_costs,
    is_active,
    created_by, created_device_name, created_device_identifier
  )
  values (
    p_product->>'sku',
    p_product->>'barcode',
    p_product->>'name',
    p_product->>'description',
    v_category_id,
    coalesce((p_product->>'base_price')::numeric(10,2), 0.0),
    coalesce((p_product->>'minimum_stock_level')::integer, 0),
    coalesce((p_product->>'maximum_stock_level')::integer, 0),
    coalesce(p_product->>'presentation_unit', 'UNIDAD'),
    v_units_per_presentation,
    p_product->>'image_url',
    case when p_product->>'extra_costs' is not null then (p_product->'extra_costs')::jsonb else '[]'::jsonb end,
    v_is_active,
    p_actor_name, p_device_name, p_device_identifier
  )
  returning * into v_product;

  if p_initial_stock > 0 then
    insert into public.inventory_documents (
      document_type,
      reference_number,
      reason,
      status,
      created_by, created_device_name, created_device_identifier
    )
    values (
      'INITIAL_INVENTORY',
      'INI-' || v_product.sku,
      'Inventario inicial en creacion de producto',
      'CONFIRMED',
      p_actor_name, p_device_name, p_device_identifier
    )
    returning id into v_stock_document_id;

    insert into public.inventory_transactions (
      product_id,
      document_id,
      transaction_type,
      quantity,
      unit_cost,
      created_by, created_device_name, created_device_identifier
    )
    values (
      v_product.id,
      v_stock_document_id,
      'IN',
      p_initial_stock,
      v_product.base_price,
      p_actor_name, p_device_name, p_device_identifier
    );
  end if;

  return v_product;
end;
$$;
