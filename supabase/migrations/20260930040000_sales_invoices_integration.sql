-- Integración Ventas/Compras: Facturas de venta y documentos de inventario atómicos

-- ============================================================
-- 1. TABLAS DE FACTURAS
-- ============================================================

create table if not exists public.sales_invoices (
  id uuid primary key default extensions.gen_random_uuid(),
  invoice_number text unique not null,
  customer_name text not null,
  customer_id uuid,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'CONFIRMED', 'CANCELLED', 'PAID')),
  total_amount numeric(18,2) not null default 0,
  currency_code char(3) not null default 'USD',
  exchange_rate numeric(18,6) not null default 1,
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
  confirmed_at timestamptz,
  cancelled_at timestamptz
);

create table if not exists public.sales_invoice_lines (
  id uuid primary key default extensions.gen_random_uuid(),
  invoice_id uuid not null references public.sales_invoices(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null check (quantity > 0),
  unit_price numeric(18,2) not null,
  discount_percent numeric(5,2) not null default 0,
  total_price numeric(18,2) not null,
  product_sku text,
  product_name text
);

alter table public.sales_invoices enable row level security;
alter table public.sales_invoice_lines enable row level security;

revoke all on public.sales_invoices from public, anon, authenticated;
revoke all on public.sales_invoice_lines from public, anon, authenticated;

grant select on public.sales_invoices to anon, authenticated;
grant select on public.sales_invoice_lines to anon, authenticated;

-- Tabla de idempotencia para facturas
create table if not exists public.sales_invoice_commands (
  command_id uuid primary key,
  payload_hash bytea not null,
  entity_id uuid references public.sales_invoices(id) on delete restrict,
  result_version integer,
  created_at timestamptz not null default now()
);

alter table public.sales_invoice_commands enable row level security;
revoke all on public.sales_invoice_commands from public, anon, authenticated;

-- ============================================================
-- 2. RPC: create_sale_invoice_with_dispatch
-- ============================================================

create or replace function public.create_sale_invoice_with_dispatch(
  p_command_id uuid,
  p_customer_name text,
  p_currency_code char(3),
  p_exchange_rate numeric,
  p_notes text,
  p_lines jsonb,
  p_warehouse_id uuid,
  p_location_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_invoices
language plpgsql security definer set search_path = '' as $$
declare
  v_hash bytea := extensions.digest(convert_to(jsonb_build_object(
    'operation', 'create_sale_invoice',
    'customer_name', btrim(p_customer_name),
    'currency_code', p_currency_code,
    'lines', p_lines,
    'warehouse_id', p_warehouse_id,
    'location_id', p_location_id
  )::text, 'UTF8'), 'sha256');
  v_invoice_id uuid;
  v_invoice public.sales_invoices%rowtype;
  v_line jsonb;
  v_total numeric := 0;
  v_document_id uuid;
begin
  -- Idempotencia
  insert into public.sales_invoice_commands(command_id, payload_hash)
  values (p_command_id, v_hash) on conflict do nothing returning command_id into v_invoice_id;
  if v_invoice_id is null then
    select entity_id into v_invoice_id from public.sales_invoice_commands where command_id = p_command_id for update;
    if (select payload_hash from public.sales_invoice_commands where command_id = p_command_id) <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_PAYLOAD_MISMATCH';
    end if;
    if v_invoice_id is null then
      raise exception using errcode = 'P0001', message = 'COMMAND_INCOMPLETE';
    end if;
    select * into v_invoice from public.sales_invoices where id = v_invoice_id;
    return v_invoice;
  end if;

  -- Calcular total
  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;

  -- Crear factura
  insert into public.sales_invoices (
    invoice_number, customer_name, status, total_amount, currency_code, exchange_rate, notes,
    created_by, created_device_name, created_device_identifier
  ) values (
    'FAC-' || lpad(nextval('public.sales_invoice_number_seq')::text, 6, '0'),
    btrim(p_customer_name),
    'CONFIRMED',
    v_total,
    p_currency_code,
    p_exchange_rate,
    p_notes,
    p_actor_name, p_device_name, p_device_identifier
  ) returning * into v_invoice;

  -- Crear líneas de factura
  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_invoice_lines (
      invoice_id, product_id, quantity, unit_price, discount_percent, total_price, product_sku, product_name
    ) values (
      v_invoice.id,
      (v_line->>'product_id')::uuid,
      (v_line->>'quantity')::integer,
      (v_line->>'unit_price')::numeric,
      coalesce((v_line->>'discount_percent')::numeric, 0),
      (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric * (1 - coalesce((v_line->>'discount_percent')::numeric, 0) / 100),
      v_line->>'product_sku',
      v_line->>'product_name'
    );
  end loop;

  -- Crear documento de inventario SALE_DISPATCH
  insert into public.inventory_documents (
    command_id, document_number, document_type, status,
    origin_warehouse_id, origin_location_id,
    external_reference, notes, confirmed_at
  ) values (
    extensions.gen_random_uuid(),
    'DES-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'),
    'SALE_DISPATCH',
    'CONFIRMED',
    p_warehouse_id,
    p_location_id,
    v_invoice.invoice_number,
    'Factura: ' || v_invoice.invoice_number,
    now()
  ) returning id into v_document_id;

  -- Crear líneas del documento de inventario
  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_document_lines (document_id, product_id, quantity)
    values (v_document_id, (v_line->>'product_id')::uuid, -(v_line->>'quantity')::integer);
  end loop;

  -- Crear transacciones de inventario (SALE)
  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier, document_id
    ) values (
      (v_line->>'product_id')::uuid,
      p_warehouse_id,
      p_location_id,
      extensions.gen_random_uuid(),
      -(v_line->>'quantity')::integer,
      'SALE',
      p_actor_name, p_device_name, p_device_identifier,
      v_document_id
    );
  end loop;

  -- Actualizar stock
  for v_line in select * from jsonb_array_elements(p_lines) loop
    update public.inventory_balances
    set quantity = quantity - (v_line->>'quantity')::integer
    where product_id = (v_line->>'product_id')::uuid and location_id = p_location_id;

    update public.products
    set current_stock = current_stock - (v_line->>'quantity')::integer
    where id = (v_line->>'product_id')::uuid;
  end loop;

  -- Vincular documento a factura
  update public.sales_invoices set inventory_document_id = v_document_id where id = v_invoice.id;

  -- Marcar comando completado
  update public.sales_invoice_commands set entity_id = v_invoice.id where command_id = p_command_id;

  -- Auditoría
  perform public.audit_payments('sales', 'sales_invoices', v_invoice.id, 'CREATE', p_actor_name, p_device_name, p_device_identifier, 'invoice', null, v_invoice.total_amount::text);

  return v_invoice;
end;
$$;

-- Secuencias
create sequence if not exists sales_invoice_number_seq start 1;
create sequence if not exists inventory_document_number_seq start 1;

revoke all on function public.create_sale_invoice_with_dispatch(uuid, text, char, numeric, text, jsonb, uuid, uuid, text, text, text) from public;
grant execute on function public.create_sale_invoice_with_dispatch(uuid, text, char, numeric, text, jsonb, uuid, uuid, text, text, text) to anon, authenticated;

-- ============================================================
-- 3. RPC: cancel_sale_invoice
-- ============================================================

create or replace function public.cancel_sale_invoice(
  p_invoice_id uuid,
  p_reason text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_invoices
language plpgsql security definer set search_path = '' as $$
declare
  v_invoice public.sales_invoices%rowtype;
  v_line public.sales_invoice_lines%rowtype;
  v_document_id uuid;
begin
  select * into v_invoice from public.sales_invoices
  where id = p_invoice_id and status = 'CONFIRMED' for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'INVOICE_NOT_CANCELLABLE';
  end if;

  -- Revertir stock
  for v_line in
    select * from public.sales_invoice_lines where invoice_id = p_invoice_id
  loop
    update public.inventory_balances
    set quantity = quantity + v_line.quantity
    where product_id = v_line.product_id;

    update public.products
    set current_stock = current_stock + v_line.quantity
    where id = v_line.product_id;
  end loop;

  -- Crear documento de devolución
  select inventory_document_id into v_document_id from public.sales_invoices where id = p_invoice_id;

  if v_document_id is not null then
    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier, document_id
    )
    select
      l.product_id,
      d.origin_warehouse_id,
      d.origin_location_id,
      extensions.gen_random_uuid(),
      l.quantity,
      'RETURN',
      p_actor_name, p_device_name, p_device_identifier,
      v_document_id
    from public.sales_invoice_lines l
    join public.inventory_documents d on d.id = v_document_id
    where l.invoice_id = p_invoice_id;
  end if;

  -- Cancelar factura
  update public.sales_invoices
  set status = 'CANCELLED',
      cancelled_at = now(),
      notes = coalesce(notes, '') || ' [CANCELLED: ' || p_reason || ']',
      updated_by = p_actor_name,
      updated_device_name = p_device_name,
      updated_device_identifier = p_device_identifier
  where id = p_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$$;

revoke all on function public.cancel_sale_invoice(uuid, text, text, text, text) from public;
grant execute on function public.cancel_sale_invoice(uuid, text, text, text, text) to anon, authenticated;
