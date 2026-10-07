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
    if cardinality(p_category_ids) <> cardinality(array(
      select distinct value from unnest(p_category_ids) as ids(value)
    )) then
      raise exception using errcode = 'P0001', message = 'DUPLICATE_CATEGORY_ORDER_ID';
    end if;
    for item_id, item_position in
      select value, ordinal::integer - 1
      from unnest(p_category_ids) with ordinality as ordered(value, ordinal)
    loop
      update public.categories
         set catalog_sort_order = item_position,
             updated_by = p_actor_name,
             updated_device_name = p_device_name,
             updated_device_identifier = p_device_identifier,
             updated_at = now()
       where id = item_id;
    end loop;
  end if;

  if p_product_ids is not null then
    if cardinality(p_product_ids) <> cardinality(array(
      select distinct value from unnest(p_product_ids) as ids(value)
    )) then
      raise exception using errcode = 'P0001', message = 'DUPLICATE_PRODUCT_ORDER_ID';
    end if;
    for item_id, item_position in
      with ordered as (
        select value as product_id, ordinal::integer,
               row_number() over (
                 partition by p.category_id order by ordinal
               )::integer - 1 as category_position
        from unnest(p_product_ids) with ordinality as input(value, ordinal)
        join public.products p on p.id = value
      )
      select product_id, category_position from ordered
    loop
      update public.products
         set catalog_sort_order = item_position,
             updated_by = p_actor_name,
             updated_device_name = p_device_name,
             updated_device_identifier = p_device_identifier,
             updated_at = now()
       where id = item_id;
    end loop;
  end if;
end;
$$;

revoke all on function public.save_catalog_order(uuid[], uuid[], text, text, text)
  from public;
grant execute on function public.save_catalog_order(uuid[], uuid[], text, text, text)
  to anon, authenticated;
