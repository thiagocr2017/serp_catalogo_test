create or replace function public.assert_valid_product_presentation_factor(
  p_product jsonb
) returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_product ? 'units_per_presentation' and (
    jsonb_typeof(p_product->'units_per_presentation') is distinct from 'number'
    or (p_product->>'units_per_presentation') !~ '^[1-9][0-9]*$'
  ) then
    raise exception using errcode = 'P0001', message = 'INVALID_PRESENTATION_FACTOR';
  end if;
end;
$$;
revoke all on function public.assert_valid_product_presentation_factor(jsonb)
  from public, anon, authenticated;

alter function public.create_product_with_initial_stock(jsonb, integer, text, text, text)
  rename to create_product_with_initial_stock_unvalidated;
revoke all on function public.create_product_with_initial_stock_unvalidated(jsonb, integer, text, text, text)
  from public, anon, authenticated;

create function public.create_product_with_initial_stock(
  p_product jsonb,
  p_initial_stock integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.products
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.assert_valid_product_presentation_factor(p_product);
  return public.create_product_with_initial_stock_unvalidated(
    p_product, p_initial_stock, p_actor_name, p_device_name, p_device_identifier
  );
end;
$$;
revoke all on function public.create_product_with_initial_stock(jsonb, integer, text, text, text)
  from public;
grant execute on function public.create_product_with_initial_stock(jsonb, integer, text, text, text)
  to anon, authenticated;

alter function public.update_product(uuid, jsonb, text, text, text)
  rename to update_product_unvalidated;
revoke all on function public.update_product_unvalidated(uuid, jsonb, text, text, text)
  from public, anon, authenticated;

create function public.update_product(
  p_product_id uuid,
  p_product jsonb,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.products
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.assert_valid_product_presentation_factor(p_product);
  return public.update_product_unvalidated(
    p_product_id, p_product, p_actor_name, p_device_name, p_device_identifier
  );
end;
$$;
revoke all on function public.update_product(uuid, jsonb, text, text, text)
  from public;
grant execute on function public.update_product(uuid, jsonb, text, text, text)
  to anon, authenticated;
