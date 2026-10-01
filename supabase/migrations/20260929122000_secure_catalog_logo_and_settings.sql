alter table public.app_settings
  add column catalog_logo_object_name text;

drop policy if exists catalog_assets_local_insert on storage.objects;
drop policy if exists catalog_assets_local_update on storage.objects;
drop policy if exists catalog_assets_local_delete on storage.objects;

create policy catalog_assets_logo_insert on storage.objects
  for insert to anon, authenticated
  with check (
    bucket_id = 'catalog-assets'
    and name ~ '^catalog-logo/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  );

create policy catalog_assets_logo_update on storage.objects
  for update to anon, authenticated
  using (
    bucket_id = 'catalog-assets'
    and name ~ '^catalog-logo/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  )
  with check (
    bucket_id = 'catalog-assets'
    and name ~ '^catalog-logo/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  );

create or replace function public.register_catalog_logo_version(
  p_operation_id uuid,
  p_object_name text,
  p_mime_type text,
  p_expected_logo_version integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.catalog_logo_rpc_result
language plpgsql security definer set search_path = '' as $$
declare
  v_hash bytea := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'register_catalog_logo',
        'object_name', p_object_name,
        'mime_type', p_mime_type,
        'expected_version', p_expected_logo_version
      )::text,
      'UTF8'
    ),
    'sha256'
  );
  v_version integer;
  v_actual_mime text;
begin
  if p_object_name !~ '^catalog-logo/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  select coalesce(metadata->>'mimetype', metadata->>'contentType')
    into v_actual_mime
    from storage.objects
   where bucket_id = 'catalog-assets' and name = p_object_name;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  if v_actual_mime not in ('image/jpeg', 'image/png', 'image/webp')
     or v_actual_mime is distinct from p_mime_type then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  insert into public.catalog_logo_operations(
    operation_id, payload_hash, object_name, result_version
  ) values (p_operation_id, v_hash, p_object_name, 0)
  on conflict do nothing;
  if not found then
    select result_version into v_version
      from public.catalog_logo_operations
     where operation_id = p_operation_id
     for update;
    if (select payload_hash from public.catalog_logo_operations
         where operation_id = p_operation_id) <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_PAYLOAD_MISMATCH';
    end if;
    if v_version = 0 then
      raise exception using errcode = 'P0001', message = 'COMMAND_INCOMPLETE';
    end if;
    return (p_object_name, v_version)::public.catalog_logo_rpc_result;
  end if;

  update public.app_settings
     set catalog_logo_object_name = p_object_name,
         catalog_logo_version = catalog_logo_version + 1
   where id = true and catalog_logo_version = p_expected_logo_version
   returning catalog_logo_version into v_version;
  if not found then
    raise exception using errcode = 'P0001', message = 'VERSION_CONFLICT';
  end if;

  update public.catalog_logo_operations
     set result_version = v_version
   where operation_id = p_operation_id;
  perform public.audit_configuration_sales(
    'configuration', 'app_settings', null, 'REGISTER_LOGO',
    p_actor_name, p_device_name, p_device_identifier,
    'catalog_logo_object_name', null, p_object_name
  );
  return (p_object_name, v_version)::public.catalog_logo_rpc_result;
end;
$$;

revoke all on function public.register_catalog_logo_version(
  uuid, text, text, integer, text, text, text
) from public;
grant execute on function public.register_catalog_logo_version(
  uuid, text, text, integer, text, text, text
) to anon, authenticated;

-- Puente local aprobado hasta que Auth reemplace la identidad del equipo.
create or replace function public.claim_local_superadmin(
  p_device_identifier text
) returns boolean
language sql security definer set search_path = '' as $$
  update public.app_settings
     set superadmin_device_identifier = p_device_identifier
   where id = true and superadmin_device_identifier is null
  returning true;
$$;
revoke all on function public.claim_local_superadmin(text) from public;
grant execute on function public.claim_local_superadmin(text)
  to anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
on table public.app_settings
from anon, authenticated;
grant select on table public.app_settings to anon, authenticated;

-- Corrección: select_catalog_agent debe retornar el nombre real del objeto
-- de logo desde app_settings, no un valor hardcodeado.
create or replace function public.select_catalog_agent(
  p_agent_id uuid,
  p_expected_version integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.catalog_preferences_rpc_result
language plpgsql security definer set search_path = '' as $$
declare
  v public.app_settings%rowtype;
begin
  select * into v from public.app_settings where id is true for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  if v.catalog_preferences_version is distinct from p_expected_version then
    raise exception using errcode = 'P0001', message = 'VERSION_CONFLICT';
  end if;
  if p_agent_id is not null and not exists(
    select 1 from public.sales_agents where id = p_agent_id and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'AGENT_INACTIVE';
  end if;
  update public.app_settings
     set selected_catalog_agent_id = p_agent_id,
         catalog_preferences_version = v.catalog_preferences_version + 1
   where id is true
  returning * into v;
  perform public.audit_configuration_sales(
    'configuration', 'app_settings', null, 'SELECT_AGENT',
    p_actor_name, p_device_name, p_device_identifier,
    'selected_catalog_agent_id', null, coalesce(p_agent_id::text, 'null')
  );
  return (
    v.catalog_cards_per_page, v.catalog_background_color,
    v.catalog_card_color, v.catalog_design_accent_color,
    v.catalog_text_color, v.catalog_highlight_text_color,
    v.catalog_secondary_text_color, v.catalog_promotion_color,
    v.catalog_promotion_text_color, v.catalog_promotion_previous_price_color,
    v.catalog_promotion_price_color, v.catalog_promotion_description_color,
    v.catalog_image_fit,
    v.catalog_logo_object_name,
    v.catalog_logo_version,
    v.selected_catalog_agent_id,
    v.catalog_preferences_version
  )::public.catalog_preferences_rpc_result;
end;
$$;

revoke all on function public.select_catalog_agent(
  uuid, integer, text, text, text
) from public;
grant execute on function public.select_catalog_agent(
  uuid, integer, text, text, text
) to anon, authenticated;
