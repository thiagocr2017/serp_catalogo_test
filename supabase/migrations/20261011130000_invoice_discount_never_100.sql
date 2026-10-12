create or replace function public.enforce_sales_invoice_line_discount()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_catalog_price numeric;
  v_promotion_price numeric;
  v_max_discount numeric := 0;
begin
  select catalog.unit_price, catalog.promo_price
    into v_catalog_price, v_promotion_price
    from public.product_catalog as catalog
   where catalog.id = new.product_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'PRODUCT_NOT_FOUND';
  end if;

  if round(new.unit_price, 2) <> round(v_catalog_price, 2) then
    raise exception using errcode = 'P0001', message = 'INVALID_UNIT_PRICE';
  end if;

  if v_promotion_price is not null and v_catalog_price > 0 then
    v_max_discount := least(
      99.99,
      greatest(0, (v_catalog_price - v_promotion_price) * 100 / v_catalog_price)
    );
  end if;

  if new.discount_percent < 0 or new.discount_percent > v_max_discount + 0.000001 then
    raise exception using errcode = 'P0001', message = 'DISCOUNT_EXCEEDS_APPROVED_PROMOTION';
  end if;

  return new;
end;
$$;
