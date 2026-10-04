-- Campos visuales/operativos de Cliente v1.

alter table public.customers
  add column if not exists display_name text,
  add column if not exists customer_type text not null default 'CASH'
    check (customer_type in ('CASH', 'CREDIT')),
  add column if not exists credit_days integer check (credit_days is null or credit_days > 0),
  add column if not exists document_preference text not null default 'E_INVOICE'
    check (document_preference in ('E_INVOICE', 'TICKET', 'ASK_EACH_TIME')),
  add column if not exists deactivation_reason text,
  add column if not exists deactivated_at timestamptz;

alter table public.customer_contacts
  add column if not exists birthday date;

drop function if exists
  public.create_customer(text, text, text, text, text, numeric, text, text, uuid, text, text, text);
drop function if exists
  public.update_customer(uuid, text, text, text, text, text, numeric, text, text, uuid, text, text, text);
drop function if exists
  public.deactivate_customer(uuid, text, text, text);
drop function if exists
  public.create_customer_contact(uuid, text, text, text, text, text, text);
drop function if exists
  public.update_customer_contact(uuid, text, text, text, text, text, text);

create or replace function public.create_customer(
  p_name text,
  p_display_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_province text,
  p_gira text,
  p_preferred_carrier_id uuid,
  p_customer_type text,
  p_credit_days integer,
  p_document_preference text,
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
  if coalesce(p_customer_type, 'CASH') = 'CREDIT'
     and (p_credit_days is null or p_credit_days <= 0) then
    raise exception using errcode = 'P0001', message = 'CREDIT_DAYS_REQUIRED';
  end if;
  if p_preferred_carrier_id is not null
     and not exists (
       select 1 from public.carriers
        where id = p_preferred_carrier_id and is_active
     ) then
    raise exception using errcode = 'P0001', message = 'CARRIER_INACTIVE';
  end if;
  insert into public.customers (
    name, display_name, phone, email, address, tax_id, credit_limit,
    province, gira, preferred_carrier_id, customer_type, credit_days,
    document_preference, created_by, created_device_name,
    created_device_identifier
  )
  values (
    btrim(p_name), nullif(btrim(p_display_name), ''), p_phone, p_email,
    p_address, p_tax_id, coalesce(p_credit_limit, 0),
    nullif(btrim(p_province), ''), nullif(btrim(p_gira), ''),
    p_preferred_carrier_id, coalesce(p_customer_type, 'CASH'),
    case when coalesce(p_customer_type, 'CASH') = 'CREDIT' then p_credit_days else null end,
    coalesce(p_document_preference, 'E_INVOICE'),
    p_actor_name, p_device_name, p_device_identifier
  )
  returning id into v_id;
  select * into v_row from public.customers where id = v_id;
  return v_row;
end;
$$;

revoke all on function public.create_customer(text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, text, text, text) from public;
grant execute on function public.create_customer(text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, text, text, text) to anon, authenticated;

create or replace function public.update_customer(
  p_customer_id uuid,
  p_name text,
  p_display_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_province text,
  p_gira text,
  p_preferred_carrier_id uuid,
  p_customer_type text,
  p_credit_days integer,
  p_document_preference text,
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
  if coalesce(p_customer_type, 'CASH') = 'CREDIT'
     and (p_credit_days is null or p_credit_days <= 0) then
    raise exception using errcode = 'P0001', message = 'CREDIT_DAYS_REQUIRED';
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
         display_name = nullif(btrim(p_display_name), ''),
         phone = p_phone,
         email = p_email,
         address = p_address,
         tax_id = p_tax_id,
         credit_limit = coalesce(p_credit_limit, 0),
         province = nullif(btrim(p_province), ''),
         gira = nullif(btrim(p_gira), ''),
         preferred_carrier_id = p_preferred_carrier_id,
         customer_type = coalesce(p_customer_type, 'CASH'),
         credit_days = case when coalesce(p_customer_type, 'CASH') = 'CREDIT' then p_credit_days else null end,
         document_preference = coalesce(p_document_preference, 'E_INVOICE'),
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

revoke all on function public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, text, text, text) from public;
grant execute on function public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, text, text, text) to anon, authenticated;

create or replace function public.deactivate_customer(
  p_customer_id uuid,
  p_reason text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'DEACTIVATION_REASON_REQUIRED';
  end if;
  update public.customers
     set is_active = false,
         deactivation_reason = btrim(p_reason),
         deactivated_at = now(),
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_customer_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
end;
$$;

revoke all on function public.deactivate_customer(uuid, text, text, text, text) from public;
grant execute on function public.deactivate_customer(uuid, text, text, text, text) to anon, authenticated;

create or replace function public.create_customer_contact(
  p_customer_id uuid,
  p_name text,
  p_phone text,
  p_role text,
  p_birthday date,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customer_contacts
language plpgsql security definer set search_path = '' as $$
declare
  v public.customer_contacts%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.customer_contacts (
    customer_id, name, phone, role, birthday,
    created_by, created_device_name, created_device_identifier
  )
  values (
    p_customer_id, btrim(p_name), p_phone, nullif(btrim(p_role), ''),
    p_birthday, p_actor_name, p_device_name, p_device_identifier
  )
  returning * into v;
  return v;
end;
$$;

revoke all on function public.create_customer_contact(uuid, text, text, text, date, text, text, text) from public;
grant execute on function public.create_customer_contact(uuid, text, text, text, date, text, text, text) to anon, authenticated;

create or replace function public.update_customer_contact(
  p_contact_id uuid,
  p_name text,
  p_phone text,
  p_role text,
  p_birthday date,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customer_contacts
language plpgsql security definer set search_path = '' as $$
declare
  v public.customer_contacts%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  update public.customer_contacts
     set name = btrim(p_name),
         phone = p_phone,
         role = nullif(btrim(p_role), ''),
         birthday = p_birthday
   where id = p_contact_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$$;

revoke all on function public.update_customer_contact(uuid, text, text, text, date, text, text, text) from public;
grant execute on function public.update_customer_contact(uuid, text, text, text, date, text, text, text) to anon, authenticated;
