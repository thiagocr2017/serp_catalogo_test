-- Keep composite return fields separate when loading local row variables.
-- Assigning a single composite expression INTO a typed composite target makes
-- PL/pgSQL try to place the whole record in its first (UUID) attribute.

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
  v_presentation public.packaging_presentations%rowtype;
  v_version integer;
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
    select entity_id, result_version into v_id, v_version
      from public.packaging_presentation_factor_commands
     where command_id = p_command_id for update;
    if (select payload_hash from public.packaging_presentation_factor_commands
         where command_id = p_command_id) <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_PAYLOAD_MISMATCH';
    end if;
    if v_id is null then
      raise exception using errcode = 'P0001', message = 'COMMAND_INCOMPLETE';
    end if;
    select * into v_presentation from public.packaging_presentations where id = v_id;
    return (v_presentation.id, v_presentation.name, v_presentation.sort_order,
      v_presentation.is_active, v_presentation.version)::public.packaging_presentation_rpc_result;
  end if;

  v_result := public.create_packaging_presentation(
    p_command_id, p_name, p_actor_name, p_device_name, p_device_identifier
  );
  v_id := (v_result).id;
  v_version := (v_result).version;
  update public.packaging_presentations
     set units_per_presentation = p_units_per_presentation
   where id = v_id;
  update public.packaging_presentation_factor_commands
     set entity_id = v_id, result_version = v_version
   where command_id = p_command_id;
  perform public.audit_configuration_sales(
    'configuration', 'packaging_presentations', v_id, 'SET_FACTOR',
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
  v_presentation public.packaging_presentations%rowtype;
  v_old_factor integer;
  v_old_name text;
begin
  if p_units_per_presentation is null or p_units_per_presentation < 1 then
    raise exception using errcode = 'P0001', message = 'INVALID_PRESENTATION_FACTOR';
  end if;
  select units_per_presentation, name into v_old_factor, v_old_name
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
   returning * into v_presentation;
  perform public.audit_configuration_sales(
    'configuration', 'packaging_presentations', p_presentation_id, 'UPDATE',
    p_actor_name, p_device_name, p_device_identifier,
    'name,units_per_presentation',
    jsonb_build_object('name', v_old_name,
      'units_per_presentation', v_old_factor)::text,
    jsonb_build_object('name', v_presentation.name,
      'units_per_presentation', p_units_per_presentation)::text
  );
  return (v_presentation.id, v_presentation.name, v_presentation.sort_order,
    v_presentation.is_active, v_presentation.version)::public.packaging_presentation_rpc_result;
exception when unique_violation then
  raise exception using errcode = 'P0001', message = 'DUPLICATE_PRESENTATION_NAME';
end;
$$;

revoke all on function public.create_packaging_presentation(uuid, text, integer, text, text, text)
  from public;
revoke all on function public.update_packaging_presentation(uuid, text, integer, integer, text, text, text)
  from public;
grant execute on function public.create_packaging_presentation(uuid, text, integer, text, text, text)
  to anon, authenticated;
grant execute on function public.update_packaging_presentation(uuid, text, integer, integer, text, text, text)
  to anon, authenticated;
