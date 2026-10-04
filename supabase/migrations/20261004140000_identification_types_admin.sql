-- Gestion del catalogo de tipos de identificacion desde Configuracion
-- (decision 23: "el catalogo es editable desde Configuracion").
--
-- Patron identico al de `carriers`: RPC SECURITY DEFINER con clave de
-- idempotencia, concurrencia optimista por `version` y auditoria. DML directo
-- sigue revocado: la tabla es de solo lectura para anon/authenticated.

alter table public.identification_types
  add column if not exists version integer not null default 1,
  add column if not exists updated_at timestamptz,
  add column if not exists updated_by text,
  add column if not exists updated_device_name text,
  add column if not exists updated_device_identifier text;

create table if not exists public.identification_type_create_commands (
  command_id uuid primary key,
  payload_hash bytea not null,
  entity_id uuid,
  result_version integer
);

revoke all on public.identification_type_create_commands
  from public, anon, authenticated;

do $$
begin
  if not exists (
    select 1 from pg_type
     where typname = 'identification_type_rpc_result'
       and typnamespace = 'public'::regnamespace
  ) then
    create type public.identification_type_rpc_result as (
      id uuid,
      code text,
      name text,
      is_active boolean,
      version integer
    );
  end if;
end $$;

create or replace function public.create_identification_type(
  p_command_id uuid,
  p_code text,
  p_name text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.identification_type_rpc_result
language plpgsql security definer set search_path = '' as $$
declare
  v_hash bytea := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'create_identification_type',
        'code', btrim(p_code),
        'name', btrim(p_name)
      )::text,
      'UTF8'
    ),
    'sha256'
  );
  v_id uuid;
  v public.identification_types%rowtype;
begin
  if btrim(p_code) = '' or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  insert into public.identification_type_create_commands(command_id, payload_hash)
  values (p_command_id, v_hash)
  on conflict do nothing
  returning command_id into v_id;

  if v_id is null then
    select entity_id into v_id
      from public.identification_type_create_commands
     where command_id = p_command_id
       for update;
    if (
      select payload_hash
        from public.identification_type_create_commands
       where command_id = p_command_id
    ) <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_PAYLOAD_MISMATCH';
    end if;
    if v_id is null or (
      select result_version
        from public.identification_type_create_commands
       where command_id = p_command_id
    ) is null then
      raise exception using errcode = 'P0001', message = 'COMMAND_INCOMPLETE';
    end if;
    select * into v from public.identification_types where id = v_id;
    return (v.id, v.code, v.name, v.is_active, v.version)
      ::public.identification_type_rpc_result;
  end if;

  v_id := extensions.gen_random_uuid();
  insert into public.identification_types (id, code, name)
  values (v_id, btrim(p_code), btrim(p_name))
  returning * into v;

  update public.identification_type_create_commands
     set entity_id = v_id,
         result_version = v.version
   where command_id = p_command_id;

  perform public.audit_configuration_sales(
    'configuration', 'identification_types', v.id, 'CREATE',
    p_actor_name, p_device_name, p_device_identifier,
    'name', null, v.name
  );
  return (v.id, v.code, v.name, v.is_active, v.version)
    ::public.identification_type_rpc_result;
exception
  when unique_violation then
    raise exception using errcode = 'P0001',
      message = 'DUPLICATE_IDENTIFICATION_TYPE_CODE';
end;
$$;

revoke all on function public.create_identification_type(uuid, text, text, text, text, text) from public;
grant execute on function public.create_identification_type(uuid, text, text, text, text, text) to anon, authenticated;

create or replace function public.update_identification_type(
  p_type_id uuid,
  p_name text,
  p_is_active boolean,
  p_expected_version integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.identification_type_rpc_result
language plpgsql security definer set search_path = '' as $$
declare
  v_old public.identification_types%rowtype;
  v public.identification_types%rowtype;
  v_name text := btrim(p_name);
begin
  if v_name = '' or p_is_active is null then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  select * into v_old
    from public.identification_types
   where id = p_type_id
     for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  if v_old.version <> p_expected_version then
    raise exception using errcode = 'P0001', message = 'VERSION_CONFLICT';
  end if;

  update public.identification_types
     set name = v_name,
         is_active = p_is_active,
         version = version + 1,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_type_id
  returning * into v;

  if v_old.name <> v.name then
    perform public.audit_configuration_sales(
      'configuration', 'identification_types', v.id, 'UPDATE',
      p_actor_name, p_device_name, p_device_identifier,
      'name', v_old.name, v.name
    );
  end if;
  if v_old.is_active <> v.is_active then
    perform public.audit_configuration_sales(
      'configuration', 'identification_types', v.id,
      case when v.is_active then 'ACTIVATE' else 'DEACTIVATE' end,
      p_actor_name, p_device_name, p_device_identifier,
      'is_active', v_old.is_active::text, v.is_active::text
    );
  end if;

  return (v.id, v.code, v.name, v.is_active, v.version)
    ::public.identification_type_rpc_result;
end;
$$;

revoke all on function public.update_identification_type(uuid, text, boolean, integer, text, text, text) from public;
grant execute on function public.update_identification_type(uuid, text, boolean, integer, text, text, text) to anon, authenticated;
