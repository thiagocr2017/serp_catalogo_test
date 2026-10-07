-- Migration: update_product_catalog_view_sorting
-- Añade la columna category_sort_order a la vista product_catalog para 
-- permitir ordenamiento jerárquico directamente en Supabase.

drop view if exists public.product_catalog;
create view public.product_catalog as
  select p.id,
    p.sku,
    p.barcode,
    p.name,
    p.description,
    p.category_id,
    p.currency_code,
    p.unit_price,
    p.package_price,
    p.min_order_quantity,
    p.cbm_per_moq,
    p.factory_cost,
    p.image_url,
    p.current_stock,
    p.reorder_point,
    coalesce(p.promo_price, round((p.unit_price * ((1)::numeric - (active_bulk.discount_percentage / (100)::numeric))), 2)) as promo_price,
        case
            when (p.promo_price is not null) then p.promo_text
            when (active_bulk.discount_percentage is not null) then concat_ws('
'::text, active_bulk.name, nullif(active_bulk.conditions_text, ''::text), nullif(active_bulk.product_conditions_text, ''::text))
            else null::text
        end as promo_text,
    p.is_active,
    p.created_at,
    p.updated_at,
    p.deleted_at,
    p.created_by,
    p.updated_by,
    p.deleted_by,
    p.created_device_name,
    p.created_device_identifier,
    p.updated_device_name,
    p.updated_device_identifier,
        case
            when (p.promo_price is not null) then 'individual'::text
            when (active_bulk.discount_percentage is not null) then 'bulk'::text
            else null::text
        end as promotion_type,
    p.minimum_sale_quantity,
    p.image_position_x,
    p.image_position_y,
    active_bulk.id as bulk_promotion_id,
    active_bulk.name as bulk_promotion_name,
    active_bulk.conditions_text as bulk_promotion_conditions,
    active_bulk.product_conditions_text as bulk_product_conditions,
    p.image_scale,
    p.catalog_sort_order,
    c.catalog_sort_order as category_sort_order,
    p.packaging_presentation_id,
    pp.name as packaging_presentation_name,
    p.extra_costs,
    pp.units_per_presentation
   from products p
     join categories c on c.id = p.category_id
     join packaging_presentations pp on pp.id = p.packaging_presentation_id
     left join lateral ( select bp.id,
            bp.name,
            bp.discount_percentage,
            bp.conditions_text,
            coalesce(bpp.conditions_text, ''::text) as product_conditions_text
           from bulk_promotions bp
             left join bulk_promotion_products bpp on bpp.promotion_id = bp.id and bpp.product_id = p.id
          where bp.is_active and (bp.start_date is null or bp.start_date <= now()) and (bp.end_date >= now()) and (bp.applies_to_all_products or bpp.product_id is not null or exists ( select 1
                   from bulk_promotion_categories bpc
                  where bpc.promotion_id = bp.id and bpc.category_id = p.category_id))
          order by bp.discount_percentage desc, bp.created_at desc
         limit 1) active_bulk on true;
