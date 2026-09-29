drop view if exists public.product_catalog;

alter table public.products drop column packaging_type;
drop type public.packaging_type;

alter table public.app_settings
  drop column packaging_unit_label,
  drop column packaging_box_label,
  drop column packaging_set_label;

create view public.product_catalog
with (security_invoker = true)
as
select
  p.id, p.sku, p.barcode, p.name, p.description, p.category_id,
  p.currency_code, p.unit_price, p.package_price, p.min_order_quantity,
  p.cbm_per_moq, p.factory_cost, p.image_url,
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
  p.image_scale, p.catalog_sort_order,
  p.packaging_presentation_id,
  pp.name as packaging_presentation_name
from public.products p
join public.packaging_presentations pp
  on pp.id = p.packaging_presentation_id
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
