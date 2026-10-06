alter table public.products
  add column if not exists units_per_presentation integer not null default 1
  check (units_per_presentation > 0);

alter table public.sales_quote_lines
  add column if not exists presentation_name text,
  add column if not exists units_per_presentation integer not null default 1
    check (units_per_presentation > 0);

create or replace view public.product_catalog with (security_invoker = true) as
select p.id, p.sku, p.barcode, p.name, p.description, p.category_id,
       p.currency_code, p.unit_price, p.package_price, p.min_order_quantity,
       p.cbm_per_moq, p.factory_cost, p.image_url, p.current_stock,
       p.reorder_point,
       coalesce(p.promo_price, round(p.unit_price * (1 - active_bulk.discount_percentage / 100), 2)) as promo_price,
       case when p.promo_price is not null then p.promo_text
            when active_bulk.discount_percentage is not null then concat_ws(E'\n', active_bulk.name,
              nullif(active_bulk.conditions_text, ''), nullif(active_bulk.product_conditions_text, ''))
            else null end as promo_text,
       p.is_active, p.created_at, p.updated_at, p.deleted_at, p.created_by,
       p.updated_by, p.deleted_by, p.created_device_name, p.created_device_identifier,
       p.updated_device_name, p.updated_device_identifier,
       case when p.promo_price is not null then 'individual'
            when active_bulk.discount_percentage is not null then 'bulk' else null end as promotion_type,
       p.minimum_sale_quantity, p.image_position_x, p.image_position_y,
       active_bulk.id as bulk_promotion_id, active_bulk.name as bulk_promotion_name,
       active_bulk.conditions_text as bulk_promotion_conditions,
       active_bulk.product_conditions_text as bulk_product_conditions,
       p.image_scale, p.catalog_sort_order, p.packaging_presentation_id,
       pp.name as packaging_presentation_name, p.extra_costs,
       p.units_per_presentation
  from public.products p
  join public.packaging_presentations pp on pp.id = p.packaging_presentation_id
  left join lateral (
    select bp.id, bp.name, bp.discount_percentage, bp.conditions_text,
           coalesce(bpp.conditions_text, '') as product_conditions_text
      from public.bulk_promotions bp
      left join public.bulk_promotion_products bpp
        on bpp.promotion_id = bp.id and bpp.product_id = p.id
     where bp.is_active and (bp.start_date is null or bp.start_date <= now())
       and bp.end_date >= now()
       and (bp.applies_to_all_products or bpp.product_id is not null or exists (
         select 1 from public.bulk_promotion_categories bpc
          where bpc.promotion_id = bp.id and bpc.category_id = p.category_id))
     order by bp.discount_percentage desc, bp.created_at desc limit 1
  ) active_bulk on true;

create or replace function public.create_product_with_initial_stock(
  p_product jsonb, p_initial_stock integer, p_actor_name text,
  p_device_name text, p_device_identifier text
) returns public.products
language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_row public.products%rowtype;
begin
  insert into public.products (
    sku, barcode, name, description, category_id, unit_price, package_price,
    min_order_quantity, minimum_sale_quantity, units_per_presentation,
    packaging_presentation_id, cbm_per_moq, factory_cost, image_position_x,
    image_position_y, image_scale, catalog_sort_order, reorder_point,
    image_url, extra_costs, created_by, created_device_name, created_device_identifier
  ) values (
    p_product->>'sku', p_product->>'barcode', p_product->>'name',
    p_product->>'description', (p_product->>'category_id')::uuid,
    (p_product->>'unit_price')::numeric, (p_product->>'package_price')::numeric,
    (p_product->>'min_order_quantity')::integer,
    (p_product->>'minimum_sale_quantity')::integer,
    coalesce((p_product->>'units_per_presentation')::integer, 1),
    (p_product->>'packaging_presentation_id')::uuid,
    (p_product->>'cbm_per_moq')::numeric, (p_product->>'factory_cost')::numeric,
    (p_product->>'image_position_x')::numeric, (p_product->>'image_position_y')::numeric,
    (p_product->>'image_scale')::numeric, (p_product->>'catalog_sort_order')::integer,
    (p_product->>'reorder_point')::integer, coalesce((p_product->>'image_url'), null),
    coalesce((p_product->>'extra_costs')::numeric, 0),
    p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_id;
  if p_initial_stock is not null and p_initial_stock <> 0 then
    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier
    )
    select v_id, w.id, l.id, extensions.gen_random_uuid(), p_initial_stock,
           'INITIAL_STOCK', p_actor_name, p_device_name, p_device_identifier
      from public.warehouses w, public.inventory_locations l
     where w.is_default and l.is_default limit 1;
  end if;
  select * into v_row from public.products where id = v_id;
  return v_row;
end;
$$;

create or replace function public.update_product(
  p_product_id uuid, p_product jsonb, p_actor_name text,
  p_device_name text, p_device_identifier text
) returns public.products
language plpgsql security definer set search_path = '' as $$
declare v public.products%rowtype;
begin
  update public.products set
    sku = coalesce(p_product->>'sku', sku),
    barcode = coalesce(p_product->>'barcode', barcode),
    name = coalesce(p_product->>'name', name),
    description = coalesce(p_product->>'description', description),
    category_id = coalesce((p_product->>'category_id')::uuid, category_id),
    unit_price = coalesce((p_product->>'unit_price')::numeric, unit_price),
    package_price = coalesce((p_product->>'package_price')::numeric, package_price),
    min_order_quantity = coalesce((p_product->>'min_order_quantity')::integer, min_order_quantity),
    minimum_sale_quantity = coalesce((p_product->>'minimum_sale_quantity')::integer, minimum_sale_quantity),
    units_per_presentation = coalesce((p_product->>'units_per_presentation')::integer, units_per_presentation),
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
    updated_by = p_actor_name, updated_device_name = p_device_name,
    updated_device_identifier = p_device_identifier
  where id = p_product_id returning * into v;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND'; end if;
  return v;
end;
$$;

create or replace function public.create_quote(
  p_customer_id uuid, p_customer_name text, p_currency_code char(3),
  p_exchange_rate numeric, p_valid_until date, p_notes text, p_agent_id uuid,
  p_lines jsonb, p_actor_name text, p_device_name text, p_device_identifier text
) returns public.sales_quotes
language plpgsql security definer set search_path = '' as $$
declare v_quote public.sales_quotes%rowtype; v_line jsonb; v_total numeric := 0;
begin
  if coalesce(btrim(p_customer_name), '') = '' or p_lines is null
     or jsonb_typeof(p_lines) is distinct from 'array'
     or coalesce(jsonb_array_length(p_lines), 0) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    if coalesce((v_line->>'quantity')::integer, 0) < 1
       or coalesce((v_line->>'unit_price')::numeric, 0) <= 0
       or coalesce((v_line->>'discount_percent')::numeric, 0) not between 0 and 100
       or coalesce((v_line->>'units_per_presentation')::integer, 1) < 1 then
      raise exception using errcode = 'P0001', message = 'INVALID_LINE';
    end if;
    v_total := v_total + (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric
      * (1 - coalesce((v_line->>'discount_percent')::numeric, 0) / 100);
  end loop;
  insert into public.sales_quotes (
    quote_number, customer_id, customer_name, status, total_amount,
    currency_code, exchange_rate, valid_until, notes, agent_id, created_by,
    created_device_name, created_device_identifier
  ) values (
    'COT-' || lpad(nextval('public.quote_number_seq')::text, 6, '0'),
    p_customer_id, btrim(p_customer_name), 'DRAFT', v_total, p_currency_code,
    p_exchange_rate, p_valid_until, p_notes, p_agent_id, p_actor_name,
    p_device_name, p_device_identifier
  ) returning * into v_quote;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_quote_lines (
      quote_id, product_id, quantity, unit_price, discount_percent, total_price,
      product_sku, product_name, presentation_name, units_per_presentation
    ) values (
      v_quote.id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer,
      (v_line->>'unit_price')::numeric,
      coalesce((v_line->>'discount_percent')::numeric, 0),
      (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric
        * (1 - coalesce((v_line->>'discount_percent')::numeric, 0) / 100),
      v_line->>'product_sku', v_line->>'product_name', v_line->>'presentation_name',
      coalesce((v_line->>'units_per_presentation')::integer, 1)
    );
  end loop;
  return v_quote;
end;
$$;

create or replace function public.update_quote(
  p_quote_id uuid, p_customer_id uuid, p_customer_name text,
  p_valid_until date, p_notes text, p_agent_id uuid, p_lines jsonb,
  p_actor_name text, p_device_name text, p_device_identifier text
) returns public.sales_quotes
language plpgsql security definer set search_path = '' as $$
declare v_quote public.sales_quotes%rowtype; v_line jsonb; v_total numeric := 0;
begin
  select * into v_quote from public.sales_quotes where id = p_quote_id for update;
  if not found then raise exception using errcode = 'P0001', message = 'NOT_FOUND'; end if;
  if v_quote.status <> 'DRAFT' then
    raise exception using errcode = 'P0001', message = 'QUOTE_NOT_EDITABLE';
  end if;
  if coalesce(btrim(p_customer_name), '') = '' or p_lines is null
     or jsonb_typeof(p_lines) is distinct from 'array'
     or coalesce(jsonb_array_length(p_lines), 0) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    if coalesce((v_line->>'quantity')::integer, 0) < 1
       or coalesce((v_line->>'unit_price')::numeric, 0) <= 0
       or coalesce((v_line->>'discount_percent')::numeric, 0) not between 0 and 100
       or coalesce((v_line->>'units_per_presentation')::integer, 1) < 1 then
      raise exception using errcode = 'P0001', message = 'INVALID_LINE';
    end if;
    v_total := v_total + (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric
      * (1 - coalesce((v_line->>'discount_percent')::numeric, 0) / 100);
  end loop;
  update public.sales_quotes set customer_id = p_customer_id,
    customer_name = btrim(p_customer_name), valid_until = p_valid_until,
    notes = p_notes, agent_id = p_agent_id, total_amount = v_total,
    updated_by = p_actor_name, updated_device_name = p_device_name,
    updated_device_identifier = p_device_identifier, updated_at = now()
  where id = p_quote_id returning * into v_quote;
  delete from public.sales_quote_lines where quote_id = p_quote_id;
  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_quote_lines (
      quote_id, product_id, quantity, unit_price, discount_percent, total_price,
      product_sku, product_name, presentation_name, units_per_presentation
    ) values (
      p_quote_id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer,
      (v_line->>'unit_price')::numeric,
      coalesce((v_line->>'discount_percent')::numeric, 0),
      (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric
        * (1 - coalesce((v_line->>'discount_percent')::numeric, 0) / 100),
      v_line->>'product_sku', v_line->>'product_name', v_line->>'presentation_name',
      coalesce((v_line->>'units_per_presentation')::integer, 1)
    );
  end loop;
  return v_quote;
end;
$$;

revoke all on function public.update_quote(uuid, uuid, text, date, text, uuid, jsonb, text, text, text) from public;
grant execute on function public.update_quote(uuid, uuid, text, date, text, uuid, jsonb, text, text, text) to anon, authenticated;
