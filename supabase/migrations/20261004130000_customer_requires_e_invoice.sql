-- requires_e_invoice (decision 20): trigger de los datos obligatorios fiscales.
-- document_preference queda como preferencia/recordatorio, no como bloqueo.

alter table public.customers
  add column if not exists requires_e_invoice boolean not null default false;

drop function if exists
  public.create_customer(text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, uuid, text, text, text, text);
drop function if exists
  public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, uuid, text, text, text, text);

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
  p_requires_e_invoice boolean,
  p_identification_type_id uuid,
  p_economic_activity text,
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
  if p_identification_type_id is not null
     and not exists (
       select 1 from public.identification_types
        where id = p_identification_type_id and is_active
     ) then
    raise exception using errcode = 'P0001', message = 'IDENTIFICATION_TYPE_INACTIVE';
  end if;
  if coalesce(p_requires_e_invoice, false) then
    if btrim(coalesce(p_tax_id, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_TAX_ID_REQUIRED';
    end if;
    if p_identification_type_id is null then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_IDENTIFICATION_TYPE_REQUIRED';
    end if;
    if btrim(coalesce(p_email, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_EMAIL_REQUIRED';
    end if;
    if btrim(coalesce(p_address, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_ADDRESS_REQUIRED';
    end if;
    if btrim(coalesce(p_economic_activity, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_ECONOMIC_ACTIVITY_REQUIRED';
    end if;
  end if;
  insert into public.customers (
    name, display_name, phone, email, address, tax_id, credit_limit,
    province, gira, preferred_carrier_id, customer_type, credit_days,
    document_preference, requires_e_invoice, identification_type_id,
    economic_activity, created_by, created_device_name,
    created_device_identifier
  )
  values (
    btrim(p_name), nullif(btrim(p_display_name), ''), p_phone, p_email,
    p_address, p_tax_id, coalesce(p_credit_limit, 0),
    nullif(btrim(p_province), ''), nullif(btrim(p_gira), ''),
    p_preferred_carrier_id, coalesce(p_customer_type, 'CASH'),
    case when coalesce(p_customer_type, 'CASH') = 'CREDIT' then p_credit_days else null end,
    coalesce(p_document_preference, 'E_INVOICE'),
    coalesce(p_requires_e_invoice, false),
    p_identification_type_id,
    nullif(btrim(p_economic_activity), ''),
    p_actor_name, p_device_name, p_device_identifier
  )
  returning id into v_id;
  select * into v_row from public.customers where id = v_id;
  return v_row;
end;
$$;

revoke all on function public.create_customer(text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) from public;
grant execute on function public.create_customer(text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) to anon, authenticated;

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
  p_requires_e_invoice boolean,
  p_identification_type_id uuid,
  p_economic_activity text,
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
  if p_identification_type_id is not null
     and not exists (
       select 1 from public.identification_types
        where id = p_identification_type_id and is_active
     ) then
    raise exception using errcode = 'P0001', message = 'IDENTIFICATION_TYPE_INACTIVE';
  end if;
  if coalesce(p_requires_e_invoice, false) then
    if btrim(coalesce(p_tax_id, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_TAX_ID_REQUIRED';
    end if;
    if p_identification_type_id is null then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_IDENTIFICATION_TYPE_REQUIRED';
    end if;
    if btrim(coalesce(p_email, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_EMAIL_REQUIRED';
    end if;
    if btrim(coalesce(p_address, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_ADDRESS_REQUIRED';
    end if;
    if btrim(coalesce(p_economic_activity, '')) = '' then
      raise exception using errcode = 'P0001', message = 'E_INVOICE_ECONOMIC_ACTIVITY_REQUIRED';
    end if;
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
         requires_e_invoice = coalesce(p_requires_e_invoice, false),
         identification_type_id = p_identification_type_id,
         economic_activity = nullif(btrim(p_economic_activity), ''),
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

revoke all on function public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) from public;
grant execute on function public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text) to anon, authenticated;
