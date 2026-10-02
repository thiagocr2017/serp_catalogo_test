-- Documentos Comerciales de Ventas: Clientes, Cotizaciones, Pedidos, Devoluciones y Consignación

-- ============================================================
-- 1. CLIENTES
-- ============================================================

create table if not exists public.customers (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  address text,
  tax_id text,
  is_active boolean not null default true,
  credit_limit numeric(18,2) not null default 0,
  current_balance numeric(18,2) not null default 0,
  created_by text,
  created_device_name text,
  created_device_identifier text,
  updated_by text,
  updated_device_name text,
  updated_device_identifier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

alter table public.customers enable row level security;
revoke all on public.customers from public, anon, authenticated;
grant select on public.customers to anon, authenticated;

-- ============================================================
-- 2. COTIZACIONES
-- ============================================================

create table if not exists public.sales_quotes (
  id uuid primary key default extensions.gen_random_uuid(),
  quote_number text unique not null,
  customer_id uuid references public.customers(id),
  customer_name text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CONVERTED')),
  total_amount numeric(18,2) not null default 0,
  currency_code char(3) not null default 'USD',
  exchange_rate numeric(18,6) not null default 1,
  valid_until date,
  notes text,
  agent_id uuid references public.sales_agents(id),
  created_by text,
  created_device_name text,
  created_device_identifier text,
  updated_by text,
  updated_device_name text,
  updated_device_identifier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.sales_quote_lines (
  id uuid primary key default extensions.gen_random_uuid(),
  quote_id uuid not null references public.sales_quotes(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null check (quantity > 0),
  unit_price numeric(18,2) not null,
  discount_percent numeric(5,2) not null default 0,
  total_price numeric(18,2) not null,
  product_sku text,
  product_name text
);

alter table public.sales_quotes enable row level security;
alter table public.sales_quote_lines enable row level security;
revoke all on public.sales_quotes from public, anon, authenticated;
revoke all on public.sales_quote_lines from public, anon, authenticated;
grant select on public.sales_quotes to anon, authenticated;
grant select on public.sales_quote_lines to anon, authenticated;

-- ============================================================
-- 3. PEDIDOS
-- ============================================================

create table if not exists public.sales_orders (
  id uuid primary key default extensions.gen_random_uuid(),
  order_number text unique not null,
  customer_id uuid references public.customers(id),
  customer_name text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'CONFIRMED', 'RESERVED', 'DISPATCHED', 'DELIVERED', 'CANCELLED')),
  total_amount numeric(18,2) not null default 0,
  currency_code char(3) not null default 'USD',
  exchange_rate numeric(18,6) not null default 1,
  notes text,
  agent_id uuid references public.sales_agents(id),
  quote_id uuid references public.sales_quotes(id),
  inventory_document_id uuid references public.inventory_documents(id),
  created_by text,
  created_device_name text,
  created_device_identifier text,
  updated_by text,
  updated_device_name text,
  updated_device_identifier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  confirmed_at timestamptz,
  cancelled_at timestamptz
);

create table if not exists public.sales_order_lines (
  id uuid primary key default extensions.gen_random_uuid(),
  order_id uuid not null references public.sales_orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null check (quantity > 0),
  unit_price numeric(18,2) not null,
  discount_percent numeric(5,2) not null default 0,
  total_price numeric(18,2) not null,
  product_sku text,
  product_name text
);

alter table public.sales_orders enable row level security;
alter table public.sales_order_lines enable row level security;
revoke all on public.sales_orders from public, anon, authenticated;
revoke all on public.sales_order_lines from public, anon, authenticated;
grant select on public.sales_orders to anon, authenticated;
grant select on public.sales_order_lines to anon, authenticated;

-- ============================================================
-- 4. DEVOLUCIONES
-- ============================================================

create table if not exists public.sales_returns (
  id uuid primary key default extensions.gen_random_uuid(),
  return_number text unique not null,
  invoice_id uuid references public.sales_invoices(id),
  customer_id uuid references public.customers(id),
  customer_name text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'CONFIRMED', 'CANCELLED')),
  total_amount numeric(18,2) not null default 0,
  currency_code char(3) not null default 'USD',
  reason text not null,
  notes text,
  inventory_document_id uuid references public.inventory_documents(id),
  created_by text,
  created_device_name text,
  created_device_identifier text,
  updated_by text,
  updated_device_name text,
  updated_device_identifier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  confirmed_at timestamptz
);

create table if not exists public.sales_return_lines (
  id uuid primary key default extensions.gen_random_uuid(),
  return_id uuid not null references public.sales_returns(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null check (quantity > 0),
  unit_price numeric(18,2) not null,
  total_price numeric(18,2) not null,
  product_sku text,
  product_name text
);

alter table public.sales_returns enable row level security;
alter table public.sales_return_lines enable row level security;
revoke all on public.sales_returns from public, anon, authenticated;
revoke all on public.sales_return_lines from public, anon, authenticated;
grant select on public.sales_returns to anon, authenticated;
grant select on public.sales_return_lines to anon, authenticated;

-- ============================================================
-- 5. CONSIGNACIÓN
-- ============================================================

create table if not exists public.sales_consignments (
  id uuid primary key default extensions.gen_random_uuid(),
  consignment_number text unique not null,
  customer_id uuid references public.customers(id),
  customer_name text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'SENT', 'PARTIAL_RETURN', 'RETURNED', 'SETTLED', 'CANCELLED')),
  total_amount numeric(18,2) not null default 0,
  returned_amount numeric(18,2) not null default 0,
  currency_code char(3) not null default 'USD',
  notes text,
  agent_id uuid references public.sales_agents(id),
  inventory_document_id uuid references public.inventory_documents(id),
  created_by text,
  created_device_name text,
  created_device_identifier text,
  updated_by text,
  updated_device_name text,
  updated_device_identifier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  confirmed_at timestamptz
);

create table if not exists public.sales_consignment_lines (
  id uuid primary key default extensions.gen_random_uuid(),
  consignment_id uuid not null references public.sales_consignments(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null check (quantity > 0),
  returned_quantity integer not null default 0,
  unit_price numeric(18,2) not null,
  total_price numeric(18,2) not null,
  product_sku text,
  product_name text
);

alter table public.sales_consignments enable row level security;
alter table public.sales_consignment_lines enable row level security;
revoke all on public.sales_consignments from public, anon, authenticated;
revoke all on public.sales_consignment_lines from public, anon, authenticated;
grant select on public.sales_consignments to anon, authenticated;
grant select on public.sales_consignment_lines to anon, authenticated;

-- ============================================================
-- 6. SECUENCIAS DE NUMERACIÓN
-- ============================================================

create sequence if not exists customer_number_seq start 1;
create sequence if not exists quote_number_seq start 1;
create sequence if not exists order_number_seq start 1;
create sequence if not exists return_number_seq start 1;
create sequence if not exists consignment_number_seq start 1;

-- ============================================================
-- 7. RPC: create_customer
-- ============================================================

create or replace function public.create_customer(
  p_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.customers (name, phone, email, address, tax_id, credit_limit, created_by, created_device_name, created_device_identifier)
  values (btrim(p_name), p_phone, p_email, p_address, p_tax_id, coalesce(p_credit_limit, 0), p_actor_name, p_device_name, p_device_identifier)
  returning id into v_id;
  return (select * from public.customers where id = v_id);
end;
$$;

revoke all on function public.create_customer(text, text, text, text, text, numeric, text, text, text) from public;
grant execute on function public.create_customer(text, text, text, text, text, numeric, text, text, text) to anon, authenticated;

-- ============================================================
-- 8. RPC: create_quote
-- ============================================================

create or replace function public.create_quote(
  p_customer_id uuid,
  p_customer_name text,
  p_currency_code char(3),
  p_exchange_rate numeric,
  p_valid_until date,
  p_notes text,
  p_agent_id uuid,
  p_lines jsonb,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_quotes
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_quote public.sales_quotes%rowtype;
  v_line jsonb;
  v_total numeric := 0;
begin
  if btrim(p_customer_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;

  insert into public.sales_quotes (quote_number, customer_id, customer_name, status, total_amount, currency_code, exchange_rate, valid_until, notes, agent_id, created_by, created_device_name, created_device_identifier)
  values ('COT-' || lpad(nextval('public.quote_number_seq')::text, 6, '0'), p_customer_id, btrim(p_customer_name), 'DRAFT', v_total, p_currency_code, p_exchange_rate, p_valid_until, p_notes, p_agent_id, p_actor_name, p_device_name, p_device_identifier)
  returning * into v_quote;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_quote_lines (quote_id, product_id, quantity, unit_price, discount_percent, total_price, product_sku, product_name)
    values (v_quote.id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer, (v_line->>'unit_price')::numeric, coalesce((v_line->>'discount_percent')::numeric, 0), (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric, v_line->>'product_sku', v_line->>'product_name');
  end loop;

  return v_quote;
end;
$$;

revoke all on function public.create_quote(uuid, text, char, numeric, date, text, uuid, jsonb, text, text, text) from public;
grant execute on function public.create_quote(uuid, text, char, numeric, date, text, uuid, jsonb, text, text, text) to anon, authenticated;

-- ============================================================
-- 9. RPC: create_order_with_reservation
-- ============================================================

create or replace function public.create_order_with_reservation(
  p_customer_id uuid,
  p_customer_name text,
  p_currency_code char(3),
  p_exchange_rate numeric,
  p_notes text,
  p_agent_id uuid,
  p_quote_id uuid,
  p_lines jsonb,
  p_warehouse_id uuid,
  p_location_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_orders
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_order public.sales_orders%rowtype;
  v_line jsonb;
  v_total numeric := 0;
  v_document_id uuid;
begin
  if btrim(p_customer_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;

  insert into public.sales_orders (order_number, customer_id, customer_name, status, total_amount, currency_code, exchange_rate, notes, agent_id, quote_id, created_by, created_device_name, created_device_identifier)
  values ('PED-' || lpad(nextval('public.order_number_seq')::text, 6, '0'), p_customer_id, btrim(p_customer_name), 'CONFIRMED', v_total, p_currency_code, p_exchange_rate, p_notes, p_agent_id, p_quote_id, p_actor_name, p_device_name, p_device_identifier)
  returning * into v_order;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_order_lines (order_id, product_id, quantity, unit_price, discount_percent, total_price, product_sku, product_name)
    values (v_order.id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer, (v_line->>'unit_price')::numeric, coalesce((v_line->>'discount_percent')::numeric, 0), (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric, v_line->>'product_sku', v_line->>'product_name');
  end loop;

  -- Crear documento de inventario SALE_DISPATCH
  insert into public.inventory_documents (command_id, document_number, document_type, status, origin_warehouse_id, origin_location_id, external_reference, notes, confirmed_at)
  values (extensions.gen_random_uuid(), 'DES-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'), 'SALE_DISPATCH', 'CONFIRMED', p_warehouse_id, p_location_id, v_order.order_number, 'Pedido: ' || v_order.order_number, now())
  returning id into v_document_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_document_lines (document_id, product_id, quantity)
    values (v_document_id, (v_line->>'product_id')::uuid, -(v_line->>'quantity')::integer);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_transactions (product_id, warehouse_id, location_id, command_id, quantity, reason, actor_name, device_name, device_identifier, document_id)
    values ((v_line->>'product_id')::uuid, p_warehouse_id, p_location_id, extensions.gen_random_uuid(), -(v_line->>'quantity')::integer, 'SALE', p_actor_name, p_device_name, p_device_identifier, v_document_id);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    update public.inventory_balances set quantity = quantity - (v_line->>'quantity')::integer
    where product_id = (v_line->>'product_id')::uuid and location_id = p_location_id;
    update public.products set current_stock = current_stock - (v_line->>'quantity')::integer
    where id = (v_line->>'product_id')::uuid;
  end loop;

  update public.sales_orders set inventory_document_id = v_document_id where id = v_order.id;

  return v_order;
end;
$$;

revoke all on function public.create_order_with_reservation(uuid, text, char, numeric, text, uuid, uuid, jsonb, uuid, uuid, text, text, text) from public;
grant execute on function public.create_order_with_reservation(uuid, text, char, numeric, text, uuid, uuid, jsonb, uuid, uuid, text, text, text) to anon, authenticated;

-- ============================================================
-- 10. RPC: create_return
-- ============================================================

create or replace function public.create_return(
  p_invoice_id uuid,
  p_customer_id uuid,
  p_customer_name text,
  p_reason text,
  p_lines jsonb,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_returns
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_return public.sales_returns%rowtype;
  v_line jsonb;
  v_total numeric := 0;
  v_document_id uuid;
begin
  if btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;

  insert into public.sales_returns (return_number, invoice_id, customer_id, customer_name, status, total_amount, reason, created_by, created_device_name, created_device_identifier)
  values ('DEV-' || lpad(nextval('public.return_number_seq')::text, 6, '0'), p_invoice_id, p_customer_id, btrim(p_customer_name), 'CONFIRMED', v_total, btrim(p_reason), p_actor_name, p_device_name, p_device_identifier)
  returning * into v_return;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_return_lines (return_id, product_id, quantity, unit_price, total_price, product_sku, product_name)
    values (v_return.id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer, (v_line->>'unit_price')::numeric, (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric, v_line->>'product_sku', v_line->>'product_name');
  end loop;

  -- Crear documento de inventario CUSTOMER_RETURN
  insert into public.inventory_documents (command_id, document_number, document_type, status, destination_warehouse_id, destination_location_id, external_reference, notes, confirmed_at)
  values (extensions.gen_random_uuid(), 'DEV-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'), 'CUSTOMER_RETURN', 'CONFIRMED', (select origin_warehouse_id from public.inventory_documents where id = (select inventory_document_id from public.sales_invoices where id = p_invoice_id)), (select origin_location_id from public.inventory_documents where id = (select inventory_document_id from public.sales_invoices where id = p_invoice_id)), v_return.return_number, 'Devolución: ' || v_return.return_number, now())
  returning id into v_document_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_document_lines (document_id, product_id, quantity)
    values (v_document_id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_transactions (product_id, warehouse_id, location_id, command_id, quantity, reason, actor_name, device_name, device_identifier, document_id)
    values ((v_line->>'product_id')::uuid, (select destination_warehouse_id from public.inventory_documents where id = v_document_id), (select destination_location_id from public.inventory_documents where id = v_document_id), extensions.gen_random_uuid(), (v_line->>'quantity')::integer, 'RETURN', p_actor_name, p_device_name, p_device_identifier, v_document_id);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    update public.inventory_balances set quantity = quantity + (v_line->>'quantity')::integer
    where product_id = (v_line->>'product_id')::uuid;
    update public.products set current_stock = current_stock + (v_line->>'quantity')::integer
    where id = (v_line->>'product_id')::uuid;
  end loop;

  update public.sales_returns set inventory_document_id = v_document_id where id = v_return.id;

  return v_return;
end;
$$;

revoke all on function public.create_return(uuid, uuid, text, text, jsonb, text, text, text) from public;
grant execute on function public.create_return(uuid, uuid, text, text, jsonb, text, text, text) to anon, authenticated;

-- ============================================================
-- 11. RPC: create_consignment
-- ============================================================

create or replace function public.create_consignment(
  p_customer_id uuid,
  p_customer_name text,
  p_currency_code char(3),
  p_notes text,
  p_agent_id uuid,
  p_lines jsonb,
  p_warehouse_id uuid,
  p_location_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_consignments
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_consignment public.sales_consignments%rowtype;
  v_line jsonb;
  v_total numeric := 0;
  v_document_id uuid;
begin
  if btrim(p_customer_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;

  insert into public.sales_consignments (consignment_number, customer_id, customer_name, status, total_amount, currency_code, notes, agent_id, created_by, created_device_name, created_device_identifier)
  values ('CON-' || lpad(nextval('public.consignment_number_seq')::text, 6, '0'), p_customer_id, btrim(p_customer_name), 'SENT', v_total, p_currency_code, p_notes, p_agent_id, p_actor_name, p_device_name, p_device_identifier)
  returning * into v_consignment;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_consignment_lines (consignment_id, product_id, quantity, returned_quantity, unit_price, total_price, product_sku, product_name)
    values (v_consignment.id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer, 0, (v_line->>'unit_price')::numeric, (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric, v_line->>'product_sku', v_line->>'product_name');
  end loop;

  -- Crear documento de inventario CONSIGNMENT
  insert into public.inventory_documents (command_id, document_number, document_type, status, origin_warehouse_id, origin_location_id, external_reference, notes, confirmed_at)
  values (extensions.gen_random_uuid(), 'CON-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'), 'CONSIGNMENT', 'CONFIRMED', p_warehouse_id, p_location_id, v_consignment.consignment_number, 'Consignación: ' || v_consignment.consignment_number, now())
  returning id into v_document_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_document_lines (document_id, product_id, quantity)
    values (v_document_id, (v_line->>'product_id')::uuid, -(v_line->>'quantity')::integer);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_transactions (product_id, warehouse_id, location_id, command_id, quantity, reason, actor_name, device_name, device_identifier, document_id)
    values ((v_line->>'product_id')::uuid, p_warehouse_id, p_location_id, extensions.gen_random_uuid(), -(v_line->>'quantity')::integer, 'SALE', p_actor_name, p_device_name, p_device_identifier, v_document_id);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    update public.inventory_balances set quantity = quantity - (v_line->>'quantity')::integer
    where product_id = (v_line->>'product_id')::uuid and location_id = p_location_id;
    update public.products set current_stock = current_stock - (v_line->>'quantity')::integer
    where id = (v_line->>'product_id')::uuid;
  end loop;

  update public.sales_consignments set inventory_document_id = v_document_id where id = v_consignment.id;

  return v_consignment;
end;
$$;

revoke all on function public.create_consignment(uuid, text, char, text, uuid, jsonb, uuid, uuid, text, text, text) from public;
grant execute on function public.create_consignment(uuid, text, char, text, uuid, jsonb, uuid, uuid, text, text, text) to anon, authenticated;
