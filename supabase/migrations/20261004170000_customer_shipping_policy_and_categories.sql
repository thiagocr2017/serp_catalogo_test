-- Políticas de pago de envío y Categorías Comerciales de Cliente
-- Decisiones 11, 37 y 38

-- 1. Política de pago de envío en clientes (Decisiones 37 y 38)
alter table public.customers
  add column if not exists shipping_payment_policy text not null default 'INCLUDED'
    check (shipping_payment_policy in ('INCLUDED', 'PREPAID', 'CASH_ON_DELIVERY'));

-- 2. Catálogo de categorías comerciales de cliente (Decisión 11)
create table if not exists public.customer_categories (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  description text,
  color text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create unique index if not exists customer_categories_name_lower_idx
  on public.customer_categories (lower(btrim(name)));

alter table public.customer_categories enable row level security;
revoke all on public.customer_categories from public, anon, authenticated;
grant select on public.customer_categories to anon, authenticated;

-- 3. Asignación múltiple cliente <-> categorías (Decisión 11)
create table if not exists public.customer_category_assignments (
  customer_id uuid not null references public.customers(id) on delete cascade,
  category_id uuid not null references public.customer_categories(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  primary key (customer_id, category_id)
);

alter table public.customer_category_assignments enable row level security;
revoke all on public.customer_category_assignments from public, anon, authenticated;
grant select on public.customer_category_assignments to anon, authenticated;

-- Precargar categorías iniciales comunes
insert into public.customer_categories (name, description)
values
  ('Mayorista', 'Clientes que compran por volumen'),
  ('Detallista', 'Clientes minoristas o de mostrador'),
  ('Distribuidor', 'Socios comerciales de distribución'),
  ('Corporativo', 'Cuentas empresariales o corporativas'),
  ('Institucional', 'Entidades gubernamentales o institucionales')
on conflict (lower(btrim(name))) do nothing;

-- 4. RPC para crear categoría de cliente
create or replace function public.create_customer_category(
  p_name text,
  p_description text default null,
  p_color text default null
) returns public.customer_categories
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.customer_categories%rowtype;
begin
  if btrim(coalesce(p_name, '')) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  insert into public.customer_categories (name, description, color, is_active)
  values (btrim(p_name), nullif(btrim(p_description), ''), nullif(btrim(p_color), ''), true)
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.create_customer_category(text, text, text) from public;
grant execute on function public.create_customer_category(text, text, text) to anon, authenticated;

-- 5. Actualizar create_customer y update_customer
drop function if exists
  public.create_customer(text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text);
drop function if exists
  public.update_customer(uuid, text, text, text, text, text, text, numeric, text, text, text, text, uuid, text, integer, text, boolean, uuid, text, text, text, text);

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
    btrim(p_name), nullif(btrim(p_display_name), ''), p_phone, p_email,
    p_address, p_tax_id, coalesce(p_credit_limit, 0),
    v_country, v_province, v_city, nullif(btrim(p_gira), ''),
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
         display_name = nullif(btrim(p_display_name), ''),
         phone = p_phone,
         email = p_email,
         address = p_address,
         tax_id = p_tax_id,
         credit_limit = coalesce(p_credit_limit, 0),
         country_code = v_country,
         province = v_province,
         city = v_city,
         gira = nullif(btrim(p_gira), ''),
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

-- 6. Actualizar customer_commercial_summary con categorías asignadas y rankings comerciales (Decisión 31)
create or replace function public.customer_commercial_summary(p_customer_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_customer public.customers%rowtype;
  v_last_purchase_at timestamptz;
  v_total_invoiced numeric(18,2) := 0;
  v_confirmed_orders_count integer := 0;
  v_pending_orders_count integer := 0;
  v_pending_quotes_count integer := 0;
  v_pending_returns_count integer := 0;
  v_pending_consignments_count integer := 0;
  v_overdue_invoices_count integer := 0;
  v_overdue_invoices_amount numeric(18,2) := 0;
  v_frequent_products jsonb := '[]'::jsonb;
  v_categories jsonb := '[]'::jsonb;
  v_rankings jsonb := '[]'::jsonb;
  v_rankings_array text[] := '{}'::text[];
begin
  select * into v_customer from public.customers where id = p_customer_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;

  -- 1. Última compra
  select max(purchased_at) into v_last_purchase_at
  from (
    select confirmed_at as purchased_at
    from public.sales_invoices
    where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
      and status in ('CONFIRMED', 'PAID')
    union all
    select coalesce(confirmed_at, created_at) as purchased_at
    from public.sales_orders
    where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
      and status in ('CONFIRMED', 'RESERVED', 'DISPATCHED', 'DELIVERED')
  ) p;

  -- 2. Total facturado
  select coalesce(sum(total_amount), 0) into v_total_invoiced
  from public.sales_invoices
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status in ('CONFIRMED', 'PAID');

  -- 3. Pedidos confirmados / despachados
  select count(*)::integer into v_confirmed_orders_count
  from public.sales_orders
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status in ('CONFIRMED', 'RESERVED', 'DISPATCHED', 'DELIVERED');

  -- 4. Documentos pendientes (Decisión 34)
  select count(*)::integer into v_pending_orders_count
  from public.sales_orders
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status in ('DRAFT', 'CONFIRMED', 'RESERVED');

  select count(*)::integer into v_pending_quotes_count
  from public.sales_quotes
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status in ('DRAFT', 'SENT');

  select count(*)::integer into v_pending_returns_count
  from public.sales_returns
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status = 'DRAFT';

  select count(*)::integer into v_pending_consignments_count
  from public.sales_consignments
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status in ('DRAFT', 'SENT', 'PARTIAL_RETURN');

  -- 5. Facturas vencidas (Decisión 34)
  select count(*)::integer, coalesce(sum(total_amount), 0)
    into v_overdue_invoices_count, v_overdue_invoices_amount
  from public.sales_invoices i
  where (i.customer_id = p_customer_id or (i.customer_id is null and i.customer_name = v_customer.name))
    and i.status = 'CONFIRMED'
    and now() > (i.created_at + make_interval(days => coalesce(v_customer.credit_days, 30)));

  -- 6. Productos frecuentes (Top 5 por cantidad acumulada, Decisión 36)
  select coalesce(jsonb_agg(sub order by sub.total_quantity desc), '[]'::jsonb)
  into v_frequent_products
  from (
    select
      lines.product_id,
      max(lines.product_name) as product_name,
      max(lines.product_sku) as product_sku,
      sum(lines.quantity)::integer as total_quantity,
      count(distinct lines.doc_id)::integer as purchase_count
    from (
      select il.invoice_id as doc_id, il.product_id, il.product_name, il.product_sku, il.quantity
      from public.sales_invoice_lines il
      join public.sales_invoices i on i.id = il.invoice_id
      where (i.customer_id = p_customer_id or (i.customer_id is null and i.customer_name = v_customer.name))
        and i.status in ('CONFIRMED', 'PAID')
      union all
      select ol.order_id as doc_id, ol.product_id, ol.product_name, ol.product_sku, ol.quantity
      from public.sales_order_lines ol
      join public.sales_orders o on o.id = ol.order_id
      where (o.customer_id = p_customer_id or (o.customer_id is null and o.customer_name = v_customer.name))
        and o.status <> 'CANCELLED'
    ) lines
    group by lines.product_id
    order by sum(lines.quantity) desc
    limit 5
  ) sub;

  -- 7. Categorías comerciales asignadas (Decisión 11)
  select coalesce(
           jsonb_agg(
             jsonb_build_object(
               'id', c.id,
               'name', c.name,
               'color', c.color
             ) order by c.name
           ),
           '[]'::jsonb
         )
    into v_categories
    from public.customer_category_assignments a
    join public.customer_categories c on c.id = a.category_id
   where a.customer_id = p_customer_id
     and c.is_active;

  -- 8. Rankings comerciales calculados (Decisión 31)
  if v_total_invoiced > 0 then
    v_rankings_array := array_append(v_rankings_array, 'Mayor Facturación');
  end if;
  if v_confirmed_orders_count >= 3 then
    v_rankings_array := array_append(v_rankings_array, 'Compra Recurrente');
  end if;
  if v_total_invoiced > 0 then
    v_rankings_array := array_append(v_rankings_array, 'Mayor Valor Histórico');
  end if;
  v_rankings := to_jsonb(v_rankings_array);

  return jsonb_build_object(
    'customer_id', p_customer_id,
    'last_purchase_at', v_last_purchase_at,
    'total_invoiced', v_total_invoiced,
    'confirmed_orders_count', v_confirmed_orders_count,
    'pending_orders_count', v_pending_orders_count,
    'pending_quotes_count', v_pending_quotes_count,
    'pending_returns_count', v_pending_returns_count,
    'pending_consignments_count', v_pending_consignments_count,
    'total_pending_documents', (
      v_pending_orders_count + v_pending_quotes_count +
      v_pending_returns_count + v_pending_consignments_count
    ),
    'overdue_invoices_count', v_overdue_invoices_count,
    'overdue_invoices_amount', v_overdue_invoices_amount,
    'frequent_products', v_frequent_products,
    'categories', v_categories,
    'commercial_rankings', v_rankings
  );
end;
$$;
