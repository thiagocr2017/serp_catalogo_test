create or replace function public.save_bulk_promotion(
  p_promotion jsonb,
  p_product_ids uuid[],
  p_category_ids uuid[],
  p_product_conditions jsonb,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
)
returns public.bulk_promotions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_promotion_id uuid := (p_promotion ->> 'id')::uuid;
  v_applies_to_all boolean := coalesce(
    (p_promotion ->> 'applies_to_all_products')::boolean,
    false
  );
  v_saved public.bulk_promotions;
  v_condition record;
  v_condition_product_id uuid;
  v_linked_product_ids uuid[] := coalesce(p_product_ids, array[]::uuid[]);
begin
  if nullif(trim(p_promotion ->> 'name'), '') is null then
    raise exception 'El nombre de la promoción es obligatorio';
  end if;

  if (p_promotion ->> 'discount_percentage')::numeric <= 0
    or (p_promotion ->> 'discount_percentage')::numeric > 100 then
    raise exception 'El descuento debe ser mayor que 0 y máximo 100';
  end if;

  if (p_promotion ->> 'end_date')::timestamptz <= now() then
    raise exception 'La fecha final debe ser posterior al momento actual';
  end if;

  if not v_applies_to_all
    and cardinality(coalesce(p_category_ids, array[]::uuid[])) = 0
    and cardinality(coalesce(p_product_ids, array[]::uuid[])) = 0 then
    raise exception 'Seleccione al menos un producto o una categoría';
  end if;

  if exists (
    select 1 from unnest(coalesce(p_category_ids, array[]::uuid[])) selected_id
    where not exists (
      select 1 from public.categories c
      where c.id = selected_id and c.is_active
    )
  ) then
    raise exception 'Una o más categorías no existen o están inactivas';
  end if;

  if exists (
    select 1 from unnest(coalesce(p_product_ids, array[]::uuid[])) selected_id
    where not exists (
      select 1 from public.products p
      where p.id = selected_id and p.is_active
    )
  ) then
    raise exception 'Uno o más productos no existen o están inactivos';
  end if;

  for v_condition in
    select key, value
    from jsonb_each_text(coalesce(p_product_conditions, '{}'::jsonb))
  loop
    v_condition_product_id := v_condition.key::uuid;
    if not exists (
      select 1
      from public.products p
      where p.id = v_condition_product_id
        and p.is_active
        and (
          v_applies_to_all
          or p.id = any(coalesce(p_product_ids, array[]::uuid[]))
          or p.category_id = any(coalesce(p_category_ids, array[]::uuid[]))
        )
    ) then
      raise exception 'La condición individual contiene un producto fuera del alcance';
    end if;
    if not (v_condition_product_id = any(v_linked_product_ids)) then
      v_linked_product_ids := array_append(
        v_linked_product_ids,
        v_condition_product_id
      );
    end if;
  end loop;

  if exists (
    select 1 from public.bulk_promotions bp where bp.id = v_promotion_id
  ) then
    update public.bulk_promotions bp
    set name = trim(p_promotion ->> 'name'),
        discount_percentage = (p_promotion ->> 'discount_percentage')::numeric,
        conditions_text = coalesce(p_promotion ->> 'conditions_text', ''),
        badge_image_url = nullif(p_promotion ->> 'badge_image_url', ''),
        start_date = nullif(p_promotion ->> 'start_date', '')::timestamptz,
        end_date = (p_promotion ->> 'end_date')::timestamptz,
        applies_to_all_products = v_applies_to_all,
        is_active = coalesce((p_promotion ->> 'is_active')::boolean, true),
        updated_by = p_actor_name,
        updated_device_name = p_device_name,
        updated_device_identifier = p_device_identifier
    where bp.id = v_promotion_id
    returning bp.* into v_saved;

    delete from public.bulk_promotion_products bpp
    where bpp.promotion_id = v_promotion_id;
    delete from public.bulk_promotion_categories bpc
    where bpc.promotion_id = v_promotion_id;
  else
    insert into public.bulk_promotions (
      id, name, discount_percentage, conditions_text, badge_image_url,
      start_date, end_date, applies_to_all_products, is_active,
      created_by, created_device_name, created_device_identifier
    ) values (
      v_promotion_id,
      trim(p_promotion ->> 'name'),
      (p_promotion ->> 'discount_percentage')::numeric,
      coalesce(p_promotion ->> 'conditions_text', ''),
      nullif(p_promotion ->> 'badge_image_url', ''),
      nullif(p_promotion ->> 'start_date', '')::timestamptz,
      (p_promotion ->> 'end_date')::timestamptz,
      v_applies_to_all,
      coalesce((p_promotion ->> 'is_active')::boolean, true),
      p_actor_name,
      p_device_name,
      p_device_identifier
    ) returning * into v_saved;
  end if;

  insert into public.bulk_promotion_products (
    promotion_id, product_id, conditions_text
  )
  select
    v_promotion_id,
    selected_product_id,
    coalesce(p_product_conditions ->> selected_product_id::text, '')
  from unnest(v_linked_product_ids) selected_product_id
  on conflict (promotion_id, product_id) do update
  set conditions_text = excluded.conditions_text;

  insert into public.bulk_promotion_categories (promotion_id, category_id)
  select v_promotion_id, selected_category_id
  from unnest(coalesce(p_category_ids, array[]::uuid[])) selected_category_id
  on conflict do nothing;

  return v_saved;
end;
$$;

grant execute on function public.save_bulk_promotion(
  jsonb, uuid[], uuid[], jsonb, text, text, text
) to anon, authenticated;
