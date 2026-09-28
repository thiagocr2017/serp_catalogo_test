alter table public.app_settings
  add column app_mode text not null default 'TEST'
    check (app_mode in ('TEST', 'PRODUCTION')),
  add column superadmin_device_identifier text;

alter table public.categories
  add column catalog_sort_order integer not null default 0;

alter table public.products
  add column catalog_sort_order integer not null default 0,
  add column image_scale numeric(4, 2) not null default 1
    check (image_scale between 1 and 3);

with ordered as (
  select id, row_number() over (order by name, id) - 1 as position
  from public.categories
)
update public.categories c
set catalog_sort_order = ordered.position
from ordered
where c.id = ordered.id;

with ordered as (
  select id, row_number() over (
    partition by category_id order by name, id
  ) - 1 as position
  from public.products
)
update public.products p
set catalog_sort_order = ordered.position
from ordered
where p.id = ordered.id;

create or replace function public.save_catalog_order(
  p_product_ids uuid[],
  p_category_ids uuid[],
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  item_id uuid;
  item_position integer;
begin
  if p_category_ids is not null then
    for item_id, item_position in
      select value, ordinal::integer - 1
      from unnest(p_category_ids) with ordinality as values_with_order(value, ordinal)
    loop
      update public.categories
      set catalog_sort_order = item_position,
          updated_by = p_actor_name,
          updated_device_name = p_device_name,
          updated_device_identifier = p_device_identifier
      where id = item_id;
    end loop;
  end if;

  if p_product_ids is not null then
    for item_id, item_position in
      select value, ordinal::integer - 1
      from unnest(p_product_ids) with ordinality as values_with_order(value, ordinal)
    loop
      update public.products
      set catalog_sort_order = item_position,
          updated_by = p_actor_name,
          updated_device_name = p_device_name,
          updated_device_identifier = p_device_identifier
      where id = item_id;
    end loop;
  end if;
end;
$$;

create or replace function public.purge_test_data_and_go_production(
  p_actor_name text,
  p_device_identifier text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  settings_row public.app_settings%rowtype;
begin
  select * into settings_row from public.app_settings where id = true for update;
  if settings_row.app_mode <> 'TEST' then
    raise exception 'The application is already in production mode';
  end if;
  if settings_row.superadmin_device_identifier is distinct from p_device_identifier then
    raise exception 'Only the configured superadmin device can purge test data';
  end if;

  delete from public.inventory_transactions;
  delete from public.audit_logs;
  delete from public.bulk_promotion_products;
  delete from public.bulk_promotion_categories;
  delete from public.bulk_promotions;
  delete from public.products;
  delete from public.categories;
  delete from storage.objects where bucket_id = 'product-images';
  delete from public.audit_logs;

  update public.app_settings
  set app_mode = 'PRODUCTION',
      updated_at = now(),
      updated_by = p_actor_name,
      updated_device_identifier = p_device_identifier
  where id = true;
end;
$$;

grant execute on function public.save_catalog_order(
  uuid[], uuid[], text, text, text
) to anon, authenticated;
grant execute on function public.purge_test_data_and_go_production(
  text, text
) to anon, authenticated;

create or replace view public.product_catalog
with (security_invoker = true)
as
select
  p.id, p.sku, p.barcode, p.name, p.description, p.category_id,
  p.currency_code, p.unit_price, p.package_price, p.min_order_quantity,
  p.packaging_type, p.cbm_per_moq, p.factory_cost, p.image_url,
  p.current_stock, p.reorder_point,
  coalesce(
    p.promo_price,
    round(p.unit_price * (1 - active_bulk.discount_percentage / 100), 2)
  ) as promo_price,
  case
    when p.promo_price is not null then p.promo_text
    when active_bulk.discount_percentage is not null then concat_ws(
      E'\n', active_bulk.name, nullif(active_bulk.conditions_text, ''),
      nullif(active_bulk.product_conditions_text, '')
    )
    else null
  end as promo_text,
  p.is_active, p.created_at, p.updated_at, p.deleted_at,
  p.created_by, p.updated_by, p.deleted_by,
  p.created_device_name, p.created_device_identifier,
  p.updated_device_name, p.updated_device_identifier,
  case
    when p.promo_price is not null then 'individual'
    when active_bulk.discount_percentage is not null then 'bulk'
    else null
  end as promotion_type,
  p.minimum_sale_quantity, p.image_position_x, p.image_position_y,
  active_bulk.id as bulk_promotion_id,
  active_bulk.name as bulk_promotion_name,
  active_bulk.conditions_text as bulk_promotion_conditions,
  active_bulk.product_conditions_text as bulk_product_conditions,
  p.image_scale, p.catalog_sort_order
from public.products p
left join lateral (
  select bp.id, bp.name, bp.discount_percentage, bp.conditions_text,
    coalesce(bpp.conditions_text, '') as product_conditions_text
  from public.bulk_promotions bp
  left join public.bulk_promotion_products bpp
    on bpp.promotion_id = bp.id and bpp.product_id = p.id
  where bp.is_active
    and (bp.start_date is null or bp.start_date <= now())
    and bp.end_date >= now()
    and (
      bp.applies_to_all_products or bpp.product_id is not null
      or exists (
        select 1 from public.bulk_promotion_categories bpc
        where bpc.promotion_id = bp.id and bpc.category_id = p.category_id
      )
    )
  order by bp.discount_percentage desc, bp.created_at desc
  limit 1
) active_bulk on true;

grant select on public.product_catalog to anon, authenticated;
