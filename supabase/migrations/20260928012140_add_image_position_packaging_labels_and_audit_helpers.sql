alter table public.products
  add column image_position_x numeric(4, 3) not null default 0.5
    check (image_position_x between 0 and 1),
  add column image_position_y numeric(4, 3) not null default 0.5
    check (image_position_y between 0 and 1);

alter table public.app_settings
  add column packaging_unit_label text not null default 'Unidad',
  add column packaging_box_label text not null default 'Caja',
  add column packaging_set_label text not null default 'Set';

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
  coalesce(p.promo_text, active_bulk.name) as promo_text,
  p.is_active, p.created_at, p.updated_at, p.deleted_at,
  p.created_by, p.updated_by, p.deleted_by,
  p.created_device_name, p.created_device_identifier,
  p.updated_device_name, p.updated_device_identifier,
  case
    when p.promo_price is not null then 'individual'
    when active_bulk.discount_percentage is not null then 'bulk'
    else null
  end as promotion_type,
  p.minimum_sale_quantity,
  p.image_position_x,
  p.image_position_y
from public.products p
left join lateral (
  select bp.name, bp.discount_percentage
  from public.bulk_promotions bp
  where bp.is_active
    and (bp.start_date is null or bp.start_date <= now())
    and bp.end_date >= now()
    and (
      bp.applies_to_all_products
      or exists (
        select 1 from public.bulk_promotion_products bpp
        where bpp.promotion_id = bp.id and bpp.product_id = p.id
      )
      or exists (
        select 1 from public.bulk_promotion_categories bpc
        where bpc.promotion_id = bp.id and bpc.category_id = p.category_id
      )
    )
  order by bp.discount_percentage desc, bp.created_at desc
  limit 1
) active_bulk on true;

grant select on public.product_catalog to anon, authenticated;
