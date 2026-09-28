create or replace function public.delete_category_and_reassign_products(
  p_category_id uuid,
  p_replacement_category_id uuid,
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
  source_name text;
  affected_products integer;
begin
  select name into source_name
  from public.categories
  where id = p_category_id and is_active
  for update;

  if source_name is null then
    raise exception 'Category not found or already deleted';
  end if;

  if (select count(*) from public.categories where is_active) <= 1 then
    raise exception 'The last active category cannot be deleted';
  end if;

  select count(*) into affected_products
  from public.products
  where category_id = p_category_id;

  if affected_products > 0 then
    if p_replacement_category_id is null
      or p_replacement_category_id = p_category_id
      or not exists (
        select 1 from public.categories
        where id = p_replacement_category_id and is_active
      ) then
      raise exception 'A different active replacement category is required';
    end if;

    update public.products
    set category_id = p_replacement_category_id,
        updated_by = p_actor_name,
        updated_device_name = p_device_name,
        updated_device_identifier = p_device_identifier
    where category_id = p_category_id;
  end if;

  delete from public.bulk_promotion_categories
  where category_id = p_category_id;

  delete from public.categories where id = p_category_id;

  insert into public.audit_logs (
    table_name, record_id, operation, field_name, old_value, new_value,
    actor_name, device_name, device_identifier
  ) values (
    'categories', p_category_id, 'SOFT_DELETE', 'category', source_name,
    case
      when p_replacement_category_id is null then 'Eliminada sin productos'
      else concat(
        'Eliminada; ', affected_products,
        ' producto(s) movidos a ', p_replacement_category_id
      )
    end,
    p_actor_name, p_device_name, p_device_identifier
  );
end;
$$;

grant execute on function public.delete_category_and_reassign_products(
  uuid, uuid, text, text, text
) to anon, authenticated;
