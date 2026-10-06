alter table public.packaging_presentations
  add column if not exists units_per_presentation integer not null default 1
    check (units_per_presentation > 0);

create or replace view public.product_catalog with (security_invoker = true) as
select p.id, p.sku, p.barcode, p.name, p.description, p.category_id,
       p.currency_code, p.unit_price, p.package_price, p.min_order_quantity,
       p.cbm_per_moq, p.factory_cost, p.image_url, p.current_stock,
       p.reorder_point,
       coalesce(p.promo_price, round(p.unit_price * (1 - active_bulk.discount_percentage / 100), 2)) as promo_price,
       case when p.promo_price is not null then p.promo_text
            when active_bulk.discount_percentage is not null then concat_ws(E'\n', active_bulk.name,
              nullif(active_bulk.conditions_text, ''), nullif(active_bulk.product_conditions_text, ''))
            else null end as promo_text,
       p.is_active, p.created_at, p.updated_at, p.deleted_at, p.created_by,
       p.updated_by, p.deleted_by, p.created_device_name, p.created_device_identifier,
       p.updated_device_name, p.updated_device_identifier,
       case when p.promo_price is not null then 'individual'
            when active_bulk.discount_percentage is not null then 'bulk' else null end as promotion_type,
       p.minimum_sale_quantity, p.image_position_x, p.image_position_y,
       active_bulk.id as bulk_promotion_id, active_bulk.name as bulk_promotion_name,
       active_bulk.conditions_text as bulk_promotion_conditions,
       active_bulk.product_conditions_text as bulk_product_conditions,
       p.image_scale, p.catalog_sort_order, p.packaging_presentation_id,
       pp.name as packaging_presentation_name, p.extra_costs,
       pp.units_per_presentation
  from public.products p
  join public.packaging_presentations pp on pp.id = p.packaging_presentation_id
  left join lateral (
    select bp.id, bp.name, bp.discount_percentage, bp.conditions_text,
           coalesce(bpp.conditions_text, '') as product_conditions_text
      from public.bulk_promotions bp
      left join public.bulk_promotion_products bpp
        on bpp.promotion_id = bp.id and bpp.product_id = p.id
     where bp.is_active and (bp.start_date is null or bp.start_date <= now())
       and bp.end_date >= now()
       and (bp.applies_to_all_products or bpp.product_id is not null or exists (
         select 1 from public.bulk_promotion_categories bpc
          where bpc.promotion_id = bp.id and bpc.category_id = p.category_id))
     order by bp.discount_percentage desc, bp.created_at desc limit 1
  ) active_bulk on true;

create table if not exists public.packaging_presentation_factor_commands (
  command_id uuid primary key,
  payload_hash bytea not null,
  entity_id uuid references public.packaging_presentations(id) on delete restrict,
  result_version integer,
  created_at timestamptz not null default now()
);
alter table public.packaging_presentation_factor_commands enable row level security;
revoke all on public.packaging_presentation_factor_commands from public, anon, authenticated;

create or replace function public.create_packaging_presentation(
  p_command_id uuid,
  p_name text,
  p_units_per_presentation integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.packaging_presentation_rpc_result
language plpgsql security definer set search_path = '' as $$
declare
  v_hash bytea;
  v_id uuid;
  v_result public.packaging_presentation_rpc_result;
  v_factor integer;
begin
  if p_units_per_presentation is null or p_units_per_presentation < 1 then
    raise exception using errcode = 'P0001', message = 'INVALID_PRESENTATION_FACTOR';
  end if;
  v_hash := extensions.digest(convert_to(jsonb_build_object(
    'operation', 'create_packaging_presentation',
    'name', btrim(p_name),
    'units_per_presentation', p_units_per_presentation
  )::text, 'UTF8'), 'sha256');
  insert into public.packaging_presentation_factor_commands(command_id, payload_hash)
  values (p_command_id, v_hash) on conflict do nothing;
  if not found then
    select entity_id, result_version into v_id, v_factor
    from public.packaging_presentation_factor_commands
    where command_id = p_command_id for update;
    if (select payload_hash from public.packaging_presentation_factor_commands
        where command_id = p_command_id) <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_PAYLOAD_MISMATCH';
    end if;
    if v_id is null then
      raise exception using errcode = 'P0001', message = 'COMMAND_INCOMPLETE';
    end if;
    select (id, name, sort_order, is_active, version)::public.packaging_presentation_rpc_result
      into v_result from public.packaging_presentations where id = v_id;
    return v_result;
  end if;
  v_result := public.create_packaging_presentation(
    p_command_id, p_name, p_actor_name, p_device_name, p_device_identifier
  );
  update public.packaging_presentations
  set units_per_presentation = p_units_per_presentation
  where id = v_result.id;
  update public.packaging_presentation_factor_commands
  set entity_id = v_result.id, result_version = v_result.version
  where command_id = p_command_id;
  perform public.audit_configuration_sales(
    'configuration', 'packaging_presentations', v_result.id, 'SET_FACTOR',
    p_actor_name, p_device_name, p_device_identifier,
    'units_per_presentation', null, p_units_per_presentation::text
  );
  return v_result;
end;
$$;

create or replace function public.update_packaging_presentation(
  p_presentation_id uuid,
  p_name text,
  p_units_per_presentation integer,
  p_expected_version integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.packaging_presentation_rpc_result
language plpgsql security definer set search_path = '' as $$
declare
  v_result public.packaging_presentation_rpc_result;
  v_old_factor integer;
begin
  if p_units_per_presentation is null or p_units_per_presentation < 1 then
    raise exception using errcode = 'P0001', message = 'INVALID_PRESENTATION_FACTOR';
  end if;
  select units_per_presentation into v_old_factor
  from public.packaging_presentations
  where id = p_presentation_id and version = p_expected_version for update;
  if not found then
    if exists (select 1 from public.packaging_presentations where id = p_presentation_id) then
      raise exception using errcode = 'P0001', message = 'VERSION_CONFLICT';
    end if;
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  update public.packaging_presentations
  set name = btrim(p_name), units_per_presentation = p_units_per_presentation,
      version = version + 1, updated_by = p_actor_name,
      updated_device_name = p_device_name,
      updated_device_identifier = p_device_identifier
  where id = p_presentation_id
  returning (id, name, sort_order, is_active, version)::public.packaging_presentation_rpc_result
  into v_result;
  perform public.audit_configuration_sales(
    'configuration', 'packaging_presentations', p_presentation_id, 'UPDATE',
    p_actor_name, p_device_name, p_device_identifier,
    'name,units_per_presentation',
    jsonb_build_object('name', p_name, 'units_per_presentation', v_old_factor)::text,
    jsonb_build_object('name', btrim(p_name), 'units_per_presentation', p_units_per_presentation)::text
  );
  return v_result;
exception when unique_violation then
  raise exception using errcode = 'P0001', message = 'DUPLICATE_PRESENTATION_NAME';
end;
$$;

revoke all on function public.create_packaging_presentation(uuid, text, integer, text, text, text) from public;
revoke all on function public.update_packaging_presentation(uuid, text, integer, integer, text, text, text) from public;
revoke all on function public.create_packaging_presentation(uuid, text, text, text, text) from anon, authenticated;
revoke all on function public.update_packaging_presentation(uuid, text, integer, text, text, text) from anon, authenticated;
grant execute on function public.create_packaging_presentation(uuid, text, integer, text, text, text) to anon, authenticated;
grant execute on function public.update_packaging_presentation(uuid, text, integer, integer, text, text, text) to anon, authenticated;
