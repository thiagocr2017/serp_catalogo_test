create table public.packaging_presentations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  created_by text,
  updated_by text,
  created_device_name text,
  created_device_identifier text,
  updated_device_name text,
  updated_device_identifier text
);

create unique index packaging_presentations_name_unique
  on public.packaging_presentations (lower(trim(name)));

alter table public.packaging_presentations enable row level security;
create policy packaging_presentations_local_access
  on public.packaging_presentations for all to anon, authenticated
  using (true) with check (true);
grant select, insert, update on public.packaging_presentations
  to anon, authenticated;

insert into public.packaging_presentations (name, sort_order)
select packaging_unit_label, 0 from public.app_settings where id = true
union all
select packaging_box_label, 1 from public.app_settings where id = true
union all
select packaging_set_label, 2 from public.app_settings where id = true
on conflict do nothing;

alter table public.products
  add column packaging_presentation_id uuid
    references public.packaging_presentations(id);

update public.products p
set packaging_presentation_id = (
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
);

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
  p.image_scale, p.catalog_sort_order,
  p.packaging_presentation_id,
  pp.name as packaging_presentation_name
from public.products p
left join public.packaging_presentations pp
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
