-- Campos mínimos obligatorios en clientes y CRUD de categorías comerciales
-- Reglas: cliente como mínimo debe tener nombre fiscal, nombre fantasía, teléfono, gira y dirección.
-- Categorías comerciales: soporte CRUD completo (create, update, delete).

-- 1. RPC para actualizar categoría de cliente
create or replace function public.update_customer_category(
  p_id uuid,
  p_name text,
  p_description text default null,
  p_color text default null,
  p_is_active boolean default true
) returns public.customer_categories
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.customer_categories%rowtype;
begin
  if not exists (select 1 from public.customer_categories where id = p_id) then
    raise exception using errcode = 'P0001', message = 'CATEGORY_NOT_FOUND';
  end if;
  if btrim(coalesce(p_name, '')) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  update public.customer_categories
     set name = btrim(p_name),
         description = nullif(btrim(p_description), ''),
         color = nullif(btrim(p_color), ''),
         is_active = coalesce(p_is_active, true),
         updated_at = now()
   where id = p_id
   returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.update_customer_category(uuid, text, text, text, boolean) from public;
grant execute on function public.update_customer_category(uuid, text, text, text, boolean) to anon, authenticated;

-- 2. RPC para eliminar categoría de cliente (con validación de uso previo)
create or replace function public.delete_customer_category(
  p_id uuid
) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.customer_categories where id = p_id) then
    raise exception using errcode = 'P0001', message = 'CATEGORY_NOT_FOUND';
  end if;

  if exists (select 1 from public.customer_category_assignments where category_id = p_id) then
    raise exception using errcode = 'P0001', message = 'CATEGORY_IN_USE';
  end if;

  delete from public.customer_categories where id = p_id;
  return true;
end;
$$;

revoke all on function public.delete_customer_category(uuid) from public;
grant execute on function public.delete_customer_category(uuid) to anon, authenticated;

-- 3. Actualizar create_customer con validaciones mínimas obligatorias
create or replace function public.create_customer(
  p_name text,
  p_display_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_country_code text,
  p_province text,
  p_city text,
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
  p_device_identifier text,
  p_shipping_payment_policy text default 'INCLUDED',
  p_category_ids uuid[] default '{}'::uuid[]
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_country text;
  v_province text;
  v_city text;
  v_area_id uuid;
  v_policy text;
  v_row public.customers%rowtype;
begin
  -- Reglas de obligatoriedad mínima para cualquier cliente
  if btrim(coalesce(p_name, '')) = '' then
    raise exception using errcode = 'P0001', message = 'NAME_REQUIRED';
  end if;
  if btrim(coalesce(p_display_name, '')) = '' then
    raise exception using errcode = 'P0001', message = 'DISPLAY_NAME_REQUIRED';
  end if;
  if btrim(coalesce(p_phone, '')) = '' then
    raise exception using errcode = 'P0001', message = 'PHONE_REQUIRED';
  end if;
  if btrim(coalesce(p_gira, '')) = '' then
    raise exception using errcode = 'P0001', message = 'GIRA_REQUIRED';
  end if;
  if btrim(coalesce(p_address, '')) = '' then
    raise exception using errcode = 'P0001', message = 'ADDRESS_REQUIRED';
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

  v_policy := coalesce(nullif(btrim(p_shipping_payment_policy), ''), 'INCLUDED');
  if v_policy not in ('INCLUDED', 'PREPAID', 'CASH_ON_DELIVERY') then
    raise exception using errcode = 'P0001', message = 'INVALID_SHIPPING_PAYMENT_POLICY';
  end if;

  v_country := coalesce(nullif(btrim(p_country_code), ''), 'CR');
  v_province := nullif(btrim(p_province), '');
  v_city := nullif(btrim(p_city), '');

  if not exists (select 1 from public.countries where code = v_country and is_active) then
    raise exception using errcode = 'P0001', message = 'COUNTRY_INACTIVE_OR_INVALID';
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

  -- Autoaprendizaje de ciudades/distritos (Decisión 29)
  if v_city is not null and v_province is not null then
    select id into v_area_id
      from public.administrative_areas
     where country_code = v_country
       and lower(btrim(name)) = lower(btrim(v_province))
     limit 1;

    insert into public.cities (
      country_code, administrative_area_id, province_name, name, is_active
    ) values (
      v_country, v_area_id, v_province, v_city, true
    ) on conflict (country_code, lower(btrim(province_name)), lower(btrim(name)))
      do nothing;
  end if;

  insert into public.customers (
    name, display_name, phone, email, address, tax_id, credit_limit,
    country_code, province, city, gira, preferred_carrier_id, customer_type, credit_days,
    document_preference, requires_e_invoice, identification_type_id,
    economic_activity, shipping_payment_policy, created_by, created_device_name,
    created_device_identifier
  )
  values (
    btrim(p_name), btrim(p_display_name), btrim(p_phone), nullif(btrim(p_email), ''),
    btrim(p_address), nullif(btrim(p_tax_id), ''), coalesce(p_credit_limit, 0),
    v_country, v_province, v_city, btrim(p_gira),
    p_preferred_carrier_id, coalesce(p_customer_type, 'CASH'),
    case when coalesce(p_customer_type, 'CASH') = 'CREDIT' then p_credit_days else null end,
    coalesce(p_document_preference, 'E_INVOICE'),
    coalesce(p_requires_e_invoice, false),
    p_identification_type_id,
    nullif(btrim(p_economic_activity), ''),
    v_policy,
    p_actor_name, p_device_name, p_device_identifier
  )
  returning id into v_id;

  -- Asignar categorías si fueron especificadas
  if p_category_ids is not null and array_length(p_category_ids, 1) > 0 then
    insert into public.customer_category_assignments (customer_id, category_id)
    select distinct v_id, cat_id
      from unnest(p_category_ids) as cat_id
     where exists (select 1 from public.customer_categories where id = cat_id and is_active)
    on conflict do nothing;
  end if;

  select * into v_row from public.customers where id = v_id;
  return v_row;
end;
$$;

revoke all on function public.create_customer(text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text, text, uuid[]) from public;
grant execute on function public.create_customer(text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text, text, uuid[]) to anon, authenticated;

-- 4. Actualizar update_customer con validaciones mínimas obligatorias
create or replace function public.update_customer(
  p_customer_id uuid,
  p_name text,
  p_display_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_country_code text,
  p_province text,
  p_city text,
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
  p_device_identifier text,
  p_shipping_payment_policy text default 'INCLUDED',
  p_category_ids uuid[] default null
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare
  v_country text;
  v_province text;
  v_city text;
  v_area_id uuid;
  v_policy text;
  v_row public.customers%rowtype;
begin
  if not exists (select 1 from public.customers where id = p_customer_id) then
    raise exception using errcode = 'P0001', message = 'CUSTOMER_NOT_FOUND';
  end if;

  -- Reglas de obligatoriedad mínima para cualquier cliente
  if btrim(coalesce(p_name, '')) = '' then
    raise exception using errcode = 'P0001', message = 'NAME_REQUIRED';
  end if;
  if btrim(coalesce(p_display_name, '')) = '' then
    raise exception using errcode = 'P0001', message = 'DISPLAY_NAME_REQUIRED';
  end if;
  if btrim(coalesce(p_phone, '')) = '' then
    raise exception using errcode = 'P0001', message = 'PHONE_REQUIRED';
  end if;
  if btrim(coalesce(p_gira, '')) = '' then
    raise exception using errcode = 'P0001', message = 'GIRA_REQUIRED';
  end if;
  if btrim(coalesce(p_address, '')) = '' then
    raise exception using errcode = 'P0001', message = 'ADDRESS_REQUIRED';
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

  v_policy := coalesce(nullif(btrim(p_shipping_payment_policy), ''), 'INCLUDED');
  if v_policy not in ('INCLUDED', 'PREPAID', 'CASH_ON_DELIVERY') then
    raise exception using errcode = 'P0001', message = 'INVALID_SHIPPING_PAYMENT_POLICY';
  end if;

  v_country := coalesce(nullif(btrim(p_country_code), ''), 'CR');
  v_province := nullif(btrim(p_province), '');
  v_city := nullif(btrim(p_city), '');

  if not exists (select 1 from public.countries where code = v_country and is_active) then
    raise exception using errcode = 'P0001', message = 'COUNTRY_INACTIVE_OR_INVALID';
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

  -- Autoaprendizaje de ciudades/distritos (Decisión 29)
  if v_city is not null and v_province is not null then
    select id into v_area_id
      from public.administrative_areas
     where country_code = v_country
       and lower(btrim(name)) = lower(btrim(v_province))
     limit 1;

    insert into public.cities (
      country_code, administrative_area_id, province_name, name, is_active
    ) values (
      v_country, v_area_id, v_province, v_city, true
    ) on conflict (country_code, lower(btrim(province_name)), lower(btrim(name)))
      do nothing;
  end if;

  update public.customers
     set name = btrim(p_name),
         display_name = btrim(p_display_name),
         phone = btrim(p_phone),
         email = nullif(btrim(p_email), ''),
         address = btrim(p_address),
         tax_id = nullif(btrim(p_tax_id), ''),
         credit_limit = coalesce(p_credit_limit, 0),
         country_code = v_country,
         province = v_province,
         city = v_city,
         gira = btrim(p_gira),
         preferred_carrier_id = p_preferred_carrier_id,
         customer_type = coalesce(p_customer_type, 'CASH'),
         credit_days = case when coalesce(p_customer_type, 'CASH') = 'CREDIT' then p_credit_days else null end,
         document_preference = coalesce(p_document_preference, 'E_INVOICE'),
         requires_e_invoice = coalesce(p_requires_e_invoice, false),
         identification_type_id = p_identification_type_id,
         economic_activity = nullif(btrim(p_economic_activity), ''),
         shipping_payment_policy = v_policy,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_customer_id;

  -- Sincronizar categorías si se pasaron
  if p_category_ids is not null then
    delete from public.customer_category_assignments where customer_id = p_customer_id;
    if array_length(p_category_ids, 1) > 0 then
      insert into public.customer_category_assignments (customer_id, category_id)
      select distinct p_customer_id, cat_id
        from unnest(p_category_ids) as cat_id
       where exists (select 1 from public.customer_categories where id = cat_id and is_active)
      on conflict do nothing;
    end if;
  end if;

  select * into v_row from public.customers where id = p_customer_id;
  return v_row;
end;
$$;

revoke all on function public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text, text, uuid[]) from public;
grant execute on function public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text, text, uuid[]) to anon, authenticated;
