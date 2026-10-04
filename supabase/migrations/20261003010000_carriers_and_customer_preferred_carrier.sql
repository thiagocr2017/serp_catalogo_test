-- Transportes globales y transporte preferido del cliente.

create table if not exists public.carriers (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  phone text,
  address text,
  contact_name text,
  notes text,
  is_active boolean not null default true,
  version integer not null default 1 check (version > 0),
  created_by text,
  updated_by text,
  created_device_name text,
  created_device_identifier text,
  updated_device_name text,
  updated_device_identifier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create unique index if not exists carriers_name_unique
  on public.carriers (lower(btrim(name)));

alter table public.carriers enable row level security;
revoke all on public.carriers from public, anon, authenticated;
grant select on public.carriers to anon, authenticated;
drop policy if exists carriers_local_access on public.carriers;
create policy carriers_local_access on public.carriers
  for all to anon, authenticated using (true);

create table if not exists public.carrier_create_commands (
  command_id uuid primary key,
  payload_hash bytea not null,
  entity_id uuid references public.carriers(id) on delete restrict,
  result_version integer,
  created_at timestamptz not null default now(),
  constraint carrier_create_commands_result_pair_check
    check (
      (entity_id is null and result_version is null)
      or (entity_id is not null and result_version is not null)
    )
);

alter table public.carrier_create_commands enable row level security;
revoke all on public.carrier_create_commands from public, anon, authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'carrier_rpc_result'
  ) then
    create type public.carrier_rpc_result as (
      id uuid,
      name text,
      phone text,
      address text,
      contact_name text,
      notes text,
      is_active boolean,
      version integer
    );
  end if;
end $$;

create or replace function public.create_carrier(
  p_command_id uuid,
  p_name text,
  p_phone text,
  p_address text,
  p_contact_name text,
  p_notes text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.carrier_rpc_result
language plpgsql security definer set search_path = '' as $$
declare
  v_hash bytea := extensions.digest(
    convert_to(
      jsonb_build_object(
        'operation', 'create_carrier',
        'name', btrim(p_name),
        'phone', nullif(btrim(p_phone), ''),
        'address', nullif(btrim(p_address), ''),
        'contact_name', nullif(btrim(p_contact_name), ''),
        'notes', nullif(btrim(p_notes), '')
      )::text,
      'UTF8'
    ),
    'sha256'
  );
  v_id uuid;
  v public.carriers%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  insert into public.carrier_create_commands(command_id, payload_hash)
  values (p_command_id, v_hash)
  on conflict do nothing
  returning command_id into v_id;

  if v_id is null then
    select entity_id into v_id
      from public.carrier_create_commands
     where command_id = p_command_id
     for update;
    if (
      select payload_hash
        from public.carrier_create_commands
       where command_id = p_command_id
    ) <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_PAYLOAD_MISMATCH';
    end if;
    if v_id is null or (
      select result_version
        from public.carrier_create_commands
       where command_id = p_command_id
    ) is null then
      raise exception using errcode = 'P0001', message = 'COMMAND_INCOMPLETE';
    end if;
    select * into v from public.carriers where id = v_id;
    return (
      v.id, v.name, v.phone, v.address, v.contact_name, v.notes,
      v.is_active, v.version
    )::public.carrier_rpc_result;
  end if;

  v_id := extensions.gen_random_uuid();
  insert into public.carriers (
    id, name, phone, address, contact_name, notes,
    created_by, created_device_name, created_device_identifier
  )
  values (
    v_id, btrim(p_name), nullif(btrim(p_phone), ''),
    nullif(btrim(p_address), ''), nullif(btrim(p_contact_name), ''),
    nullif(btrim(p_notes), ''),
    p_actor_name, p_device_name, p_device_identifier
  )
  returning * into v;
  update public.carrier_create_commands
     set entity_id = v_id,
         result_version = v.version
   where command_id = p_command_id;
  perform public.audit_configuration_sales(
    'configuration', 'carriers', v.id, 'CREATE',
    p_actor_name, p_device_name, p_device_identifier,
    'name', null, v.name
  );
  return (
    v.id, v.name, v.phone, v.address, v.contact_name, v.notes,
    v.is_active, v.version
  )::public.carrier_rpc_result;
exception
  when unique_violation then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_CARRIER_NAME';
end;
$$;

create or replace function public.update_carrier(
  p_carrier_id uuid,
  p_name text,
  p_phone text,
  p_address text,
  p_contact_name text,
  p_notes text,
  p_expected_version integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.carrier_rpc_result
language plpgsql security definer set search_path = '' as $$
declare
  v public.carriers%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  update public.carriers
     set name = btrim(p_name),
         phone = nullif(btrim(p_phone), ''),
         address = nullif(btrim(p_address), ''),
         contact_name = nullif(btrim(p_contact_name), ''),
         notes = nullif(btrim(p_notes), ''),
         version = version + 1,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_carrier_id
     and version = p_expected_version
  returning * into v;
  if not found then
    if exists (select 1 from public.carriers where id = p_carrier_id) then
      raise exception using errcode = 'P0001', message = 'VERSION_CONFLICT';
    end if;
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  perform public.audit_configuration_sales(
    'configuration', 'carriers', v.id, 'UPDATE',
    p_actor_name, p_device_name, p_device_identifier,
    'carrier', null, v.name
  );
  return (
    v.id, v.name, v.phone, v.address, v.contact_name, v.notes,
    v.is_active, v.version
  )::public.carrier_rpc_result;
exception
  when unique_violation then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_CARRIER_NAME';
end;
$$;

revoke all on function
  public.create_carrier(uuid, text, text, text, text, text, text, text, text),
  public.update_carrier(uuid, text, text, text, text, text, integer, text, text, text)
from public;
grant execute on function
  public.create_carrier(uuid, text, text, text, text, text, text, text, text),
  public.update_carrier(uuid, text, text, text, text, text, integer, text, text, text)
to anon, authenticated;

alter table public.customers
  add column if not exists preferred_carrier_id uuid
    references public.carriers(id) on delete set null;

drop function if exists
  public.create_customer(text, text, text, text, text, numeric, text, text, text, text, text);
drop function if exists
  public.update_customer(uuid, text, text, text, text, text, numeric, text, text, text, text, text);

create or replace function public.create_customer(
  p_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_province text,
  p_gira text,
  p_preferred_carrier_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_row public.customers%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if p_preferred_carrier_id is not null
     and not exists (
       select 1 from public.carriers
        where id = p_preferred_carrier_id and is_active
     ) then
    raise exception using errcode = 'P0001', message = 'CARRIER_INACTIVE';
  end if;
  insert into public.customers (
    name, phone, email, address, tax_id, credit_limit,
    province, gira, preferred_carrier_id,
    created_by, created_device_name, created_device_identifier
  )
  values (
    btrim(p_name), p_phone, p_email, p_address, p_tax_id,
    coalesce(p_credit_limit, 0),
    nullif(btrim(p_province), ''), nullif(btrim(p_gira), ''),
    p_preferred_carrier_id,
    p_actor_name, p_device_name, p_device_identifier
  )
  returning id into v_id;
  select * into v_row from public.customers where id = v_id;
  return v_row;
end;
$$;

revoke all on function public.create_customer(text, text, text, text, text, numeric, text, text, uuid, text, text, text) from public;
grant execute on function public.create_customer(text, text, text, text, text, numeric, text, text, uuid, text, text, text) to anon, authenticated;

create or replace function public.update_customer(
  p_customer_id uuid,
  p_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_province text,
  p_gira text,
  p_preferred_carrier_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare
  v public.customers%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if p_preferred_carrier_id is not null
     and not exists (
       select 1 from public.carriers
        where id = p_preferred_carrier_id and is_active
     ) then
    raise exception using errcode = 'P0001', message = 'CARRIER_INACTIVE';
  end if;
  update public.customers
     set name = btrim(p_name),
         phone = p_phone,
         email = p_email,
         address = p_address,
         tax_id = p_tax_id,
         credit_limit = coalesce(p_credit_limit, 0),
         province = nullif(btrim(p_province), ''),
         gira = nullif(btrim(p_gira), ''),
         preferred_carrier_id = p_preferred_carrier_id,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_customer_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$$;

revoke all on function public.update_customer(uuid, text, text, text, text, text, numeric, text, text, uuid, text, text, text) from public;
grant execute on function public.update_customer(uuid, text, text, text, text, text, numeric, text, text, uuid, text, text, text) to anon, authenticated;
