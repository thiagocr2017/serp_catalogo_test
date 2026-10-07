-- Atomic customer returns across Sales, Inventory and Payments.
-- Sales owns the aggregate; child writes remain behind module RPCs.

alter table public.inventory_locations
  add column if not exists stock_role text not null default 'SELLABLE'
  check (stock_role in ('SELLABLE', 'QUARANTINE'));
alter table public.inventory_locations
  add constraint inventory_quarantine_not_default_check
  check (stock_role <> 'QUARANTINE' or not is_default);

insert into public.inventory_locations (warehouse_id, code, name, is_default, stock_role)
select w.id, 'Q-DEV', 'Cuarentena de devoluciones', false, 'QUARANTINE'
  from public.warehouses w
 where not exists (
   select 1 from public.inventory_locations l
    where l.warehouse_id = w.id and l.stock_role = 'QUARANTINE'
 );

alter table public.inventory_document_lines
  add column if not exists sales_return_line_id uuid,
  add column if not exists condition_snapshot text
    check (condition_snapshot is null or condition_snapshot in ('GOOD', 'DAMAGED'));

alter table public.sales_returns
  add column if not exists command_id uuid,
  add column if not exists debt_reduction_amount numeric(18,2) not null default 0,
  add column if not exists financial_resolution text
    check (financial_resolution is null or financial_resolution in ('REFUND', 'CUSTOMER_CREDIT')),
  add column if not exists financial_resolution_amount numeric(18,2) not null default 0,
  add column if not exists payment_effect_id uuid,
  add column if not exists updated_at timestamptz;

alter table public.sales_return_lines
  add constraint sales_return_line_positive_quantity_check check (quantity > 0);

alter table public.sales_return_lines
  add column if not exists condition text not null default 'GOOD'
    check (condition in ('GOOD', 'DAMAGED')),
  add column if not exists inventory_location_id uuid
    references public.inventory_locations(id) on delete restrict,
  add column if not exists original_net_unit_price numeric(18,4),
  add column if not exists active_invoice_line_id uuid;

update public.sales_return_lines rl
   set original_net_unit_price = round(
     il.total_price / nullif(il.quantity, 0), 4
   )
  from public.sales_invoice_lines il
 where il.id = rl.invoice_line_id
   and rl.original_net_unit_price is null;

create unique index if not exists sales_returns_command_id_uidx
  on public.sales_returns(command_id) where command_id is not null;
update public.sales_return_lines rl set active_invoice_line_id = rl.invoice_line_id
 where rl.invoice_line_id is not null
   and exists (select 1 from public.sales_returns r where r.id = rl.return_id and r.status <> 'CANCELLED');
create unique index if not exists sales_returns_active_invoice_line_uidx
  on public.sales_return_lines(active_invoice_line_id)
  where active_invoice_line_id is not null;
create unique index if not exists inventory_document_return_line_uidx
  on public.inventory_document_lines(sales_return_line_id)
  where sales_return_line_id is not null;
create index if not exists inventory_balances_location_product_idx
  on public.inventory_balances(location_id, product_id);

alter table public.payment_applications
  add column if not exists currency_code char(3),
  add column if not exists exchange_rate numeric(18,6),
  add column if not exists usd_equivalent numeric(18,2),
  add column if not exists command_id uuid;

alter table public.refunds
  add column if not exists sales_return_id uuid,
  add column if not exists invoice_id uuid,
  add column if not exists command_id uuid;

alter table public.customer_credit_entries
  add column if not exists sales_return_id uuid,
  add column if not exists invoice_id uuid,
  add column if not exists command_id uuid;

create table if not exists public.payment_return_settlements (
  id uuid primary key default extensions.gen_random_uuid(),
  command_id uuid not null unique,
  payload_hash bytea not null,
  sales_return_id uuid not null unique,
  invoice_id uuid not null,
  customer_id uuid not null,
  currency_code char(3) not null,
  amount numeric(18,2) not null check (amount > 0),
  resolution text not null check (resolution in ('REFUND', 'CUSTOMER_CREDIT')),
  created_at timestamptz not null default now()
);
alter table public.payment_return_settlements enable row level security;
revoke all on public.payment_return_settlements from public, anon, authenticated;
drop index if exists public.refunds_sales_return_uidx;
create unique index if not exists customer_credit_return_uidx
  on public.customer_credit_entries(sales_return_id)
  where sales_return_id is not null;
create unique index if not exists refunds_command_id_uidx
  on public.refunds(command_id) where command_id is not null;
create unique index if not exists customer_credit_command_id_uidx
  on public.customer_credit_entries(command_id) where command_id is not null;

alter table public.sales_return_lines enable row level security;
revoke insert, update, delete, truncate on public.sales_returns from public, anon, authenticated;
revoke insert, update, delete, truncate on public.sales_return_lines from public, anon, authenticated;
revoke insert, update, delete, truncate on public.inventory_documents from public, anon, authenticated;
revoke insert, update, delete, truncate on public.inventory_document_lines from public, anon, authenticated;
revoke insert, update, delete, truncate on public.inventory_transactions from public, anon, authenticated;
revoke insert, update, delete, truncate on public.payment_applications from public, anon, authenticated;
revoke insert, update, delete, truncate on public.refunds from public, anon, authenticated;
revoke insert, update, delete, truncate on public.customer_credit_entries from public, anon, authenticated;

create or replace function public.sales_return_line_set_active_invoice_line()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.invoice_line_id is not null and exists (
    select 1 from public.sales_returns r where r.id = new.return_id and r.status <> 'CANCELLED'
  ) then
    new.active_invoice_line_id := new.invoice_line_id;
  else
    new.active_invoice_line_id := null;
  end if;
  return new;
end;
$$;
create trigger sales_return_line_active_reference
before insert on public.sales_return_lines
for each row execute function public.sales_return_line_set_active_invoice_line();

create or replace function public.sales_return_sync_active_lines()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status is distinct from new.status then
    update public.sales_return_lines
       set active_invoice_line_id = case when new.status = 'CANCELLED'
           then null else invoice_line_id end
     where return_id = new.id;
  end if;
  return new;
end;
$$;
create trigger sales_return_status_sync_lines
after update of status on public.sales_returns
for each row execute function public.sales_return_sync_active_lines();

-- Remove every callable legacy signature that accepts caller-supplied prices.
revoke all on function public.create_return(uuid, uuid, text, text, jsonb, text, text, text)
  from public, anon, authenticated;

create or replace function public.apply_inventory_transaction()
returns trigger language plpgsql set search_path = '' as $$
begin
  insert into public.inventory_balances (
    product_id, warehouse_id, location_id, quantity, updated_at
  ) values (new.product_id, new.warehouse_id, new.location_id, new.quantity, now())
  on conflict (product_id, location_id) do update
    set quantity = public.inventory_balances.quantity + excluded.quantity,
        warehouse_id = excluded.warehouse_id, updated_at = now();
  update public.products p
     set current_stock = coalesce((
       select sum(b.quantity)::integer from public.inventory_balances b
       join public.inventory_locations l on l.id = b.location_id
       where b.product_id = p.id and l.stock_role = 'SELLABLE'
     ), 0),
         updated_by = coalesce(new.actor_name, 'device:' || new.device_identifier),
         updated_device_name = new.device_name,
         updated_device_identifier = new.device_identifier
   where p.id = new.product_id;
  if not found then raise exception 'El producto % no existe', new.product_id; end if;
  return new;
end;
$$;

create or replace function public.create_sale_invoice_with_dispatch(
  p_command_id uuid, p_customer_id uuid, p_customer_name text,
  p_currency_code char(3), p_exchange_rate numeric, p_notes text,
  p_lines jsonb, p_warehouse_id uuid, p_actor_name text,
  p_device_name text, p_device_identifier text
) returns public.sales_invoices
language plpgsql security definer set search_path = '' as $$
declare
  v_hash bytea := extensions.digest(convert_to(jsonb_build_object(
    'operation', 'create_sale_invoice', 'customer_id', p_customer_id,
    'customer_name', btrim(p_customer_name), 'currency_code', p_currency_code,
    'exchange_rate', p_exchange_rate, 'notes', p_notes,
    'lines', p_lines, 'warehouse_id', p_warehouse_id
  )::text, 'UTF8'), 'sha256');
  v_existing public.sales_invoice_commands%rowtype;
  v_invoice public.sales_invoices%rowtype;
  v_command_id uuid;
  v_document_id uuid;
  v_line jsonb;
  v_balance record;
  v_available integer;
  v_to_allocate integer;
  v_total numeric := 0;
  v_unit integer;
  v_quantity integer;
begin
  if p_customer_id is null or btrim(coalesce(p_customer_name, '')) = ''
     or p_exchange_rate is null or p_exchange_rate <= 0 or p_lines is null
     or jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if not exists (select 1 from public.customers where id = p_customer_id and is_active) then
    raise exception using errcode = 'P0001', message = 'CUSTOMER_INACTIVE';
  end if;
  if not exists (select 1 from public.warehouses where id = p_warehouse_id and is_active) then
    raise exception using errcode = 'P0001', message = 'WAREHOUSE_INACTIVE';
  end if;
  insert into public.sales_invoice_commands(command_id, payload_hash)
    values (p_command_id, v_hash) on conflict do nothing returning command_id into v_command_id;
  if v_command_id is null then
    select * into v_existing from public.sales_invoice_commands where command_id = p_command_id for update;
    if v_existing.payload_hash <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_PAYLOAD_MISMATCH';
    end if;
    if v_existing.entity_id is null then
      raise exception using errcode = 'P0001', message = 'COMMAND_INCOMPLETE';
    end if;
    select * into v_invoice from public.sales_invoices where id = v_existing.entity_id;
    return v_invoice;
  end if;
  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_quantity := (v_line->>'quantity')::integer;
    if v_quantity <= 0 or coalesce((v_line->>'unit_price')::numeric, 0) <= 0
       or coalesce((v_line->>'discount_percent')::numeric, 0) not between 0 and 100
       or not exists (select 1 from public.products where id = (v_line->>'product_id')::uuid and is_active) then
      raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
    end if;
    v_total := v_total + round(v_quantity * (v_line->>'unit_price')::numeric *
      (1 - coalesce((v_line->>'discount_percent')::numeric, 0) / 100), 2);
  end loop;
  perform 1 from public.inventory_balances b
    join public.inventory_locations l on l.id = b.location_id
   where b.warehouse_id = p_warehouse_id and l.is_active and l.stock_role = 'SELLABLE'
     and b.product_id in (select (value->>'product_id')::uuid from jsonb_array_elements(p_lines))
   order by b.product_id, b.location_id for update of b;
  for v_line in
    select jsonb_build_object('product_id', requested.product_id,
      'quantity', sum(requested.quantity)::integer)
      from (select (value->>'product_id')::uuid as product_id,
        (value->>'quantity')::integer as quantity from jsonb_array_elements(p_lines)) requested
     group by requested.product_id
  loop
    select coalesce(sum(greatest(b.quantity - b.reserved_quantity, 0)), 0)::integer
      into v_available from public.inventory_balances b
      join public.inventory_locations l on l.id = b.location_id
     where b.product_id = (v_line->>'product_id')::uuid
       and b.warehouse_id = p_warehouse_id and l.is_active and l.stock_role = 'SELLABLE';
    if v_available < (v_line->>'quantity')::integer then
      raise exception using errcode = 'P0001', message = 'INSUFFICIENT_STOCK';
    end if;
  end loop;
  insert into public.sales_invoices(invoice_number, customer_id, customer_name,
    status, total_amount, currency_code, exchange_rate, notes, created_by,
    created_device_name, created_device_identifier, confirmed_at)
  values ('FAC-' || lpad(nextval('public.sales_invoice_number_seq')::text, 6, '0'),
    p_customer_id, btrim(p_customer_name), 'CONFIRMED', v_total, p_currency_code,
    p_exchange_rate, p_notes, p_actor_name, p_device_name, p_device_identifier, now())
  returning * into v_invoice;
  insert into public.inventory_documents(command_id, document_number, document_type,
    status, origin_warehouse_id, external_reference, notes, confirmed_at)
  values (extensions.gen_random_uuid(),
    'DES-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'),
    'SALE_DISPATCH', 'CONFIRMED', p_warehouse_id, v_invoice.invoice_number,
    'Factura: ' || v_invoice.invoice_number, now()) returning id into v_document_id;
  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_quantity := (v_line->>'quantity')::integer;
    insert into public.sales_invoice_lines(invoice_id, product_id, quantity,
      unit_price, discount_percent, total_price, product_sku, product_name)
    values (v_invoice.id, (v_line->>'product_id')::uuid, v_quantity,
      (v_line->>'unit_price')::numeric, coalesce((v_line->>'discount_percent')::numeric, 0),
      round(v_quantity * (v_line->>'unit_price')::numeric *
        (1 - coalesce((v_line->>'discount_percent')::numeric, 0) / 100), 2),
      v_line->>'product_sku', v_line->>'product_name');
    insert into public.inventory_document_lines(document_id, product_id, quantity)
      values (v_document_id, (v_line->>'product_id')::uuid, -v_quantity);
    v_to_allocate := v_quantity;
    for v_balance in select b.location_id, b.quantity, b.reserved_quantity, l.is_default, l.code
      from public.inventory_balances b join public.inventory_locations l on l.id = b.location_id
     where b.product_id = (v_line->>'product_id')::uuid and b.warehouse_id = p_warehouse_id
       and l.is_active and l.stock_role = 'SELLABLE' and b.quantity > b.reserved_quantity
     order by l.is_default desc, l.code, b.location_id for update of b
    loop
      exit when v_to_allocate = 0;
      v_available := v_balance.quantity - v_balance.reserved_quantity;
      v_unit := least(v_available, v_to_allocate);
      insert into public.inventory_transactions(product_id, warehouse_id, location_id,
        command_id, quantity, reason, actor_name, device_name, device_identifier, document_id)
      values ((v_line->>'product_id')::uuid, p_warehouse_id, v_balance.location_id,
        extensions.gen_random_uuid(), -v_unit, 'SALE', p_actor_name, p_device_name,
        p_device_identifier, v_document_id);
      v_to_allocate := v_to_allocate - v_unit;
    end loop;
    if v_to_allocate > 0 then
      raise exception using errcode = 'P0001', message = 'INSUFFICIENT_STOCK';
    end if;
  end loop;
  update public.sales_invoices set inventory_document_id = v_document_id where id = v_invoice.id;
  update public.sales_invoice_commands set entity_id = v_invoice.id where command_id = p_command_id;
  perform public.audit_payments('sales', 'sales_invoices', v_invoice.id, 'CREATE',
    p_actor_name, p_device_name, p_device_identifier, 'invoice', null, v_invoice.total_amount::text);
  select * into v_invoice from public.sales_invoices where id = v_invoice.id;
  return v_invoice;
end;
$$;

create or replace function public.inventory_receive_sales_return(
  p_command_id uuid,
  p_return_id uuid,
  p_return_number text,
  p_lines jsonb,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_document_id uuid;
  v_line jsonb;
  v_location public.inventory_locations%rowtype;
  v_product_id uuid;
  v_quantity integer;
  v_condition text;
  v_doc_line_id uuid;
begin
  if p_command_id is null or p_return_id is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  select id into v_document_id from public.inventory_documents
   where command_id = p_command_id;
  if v_document_id is not null then return v_document_id; end if;

  insert into public.inventory_documents (
    command_id, document_number, document_type, status,
    external_reference, notes, confirmed_at, created_by,
    created_device_name, created_device_identifier
  ) values (
    p_command_id,
    'DEV-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'),
    'CUSTOMER_RETURN', 'CONFIRMED', p_return_number,
    'Recepcion por devolucion ' || p_return_number, now(),
    p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_document_id;

  for v_line in select value from jsonb_array_elements(p_lines) order by value->>'invoice_line_id' loop
    v_product_id := (v_line->>'product_id')::uuid;
    v_quantity := (v_line->>'quantity')::integer;
    v_condition := v_line->>'condition';
    select * into v_location from public.inventory_locations
     where id = (v_line->>'location_id')::uuid and is_active for update;
    if not found or (v_condition = 'GOOD' and v_location.stock_role <> 'SELLABLE')
       or (v_condition = 'DAMAGED' and v_location.stock_role <> 'QUARANTINE') then
      raise exception using errcode = 'P0001', message = 'LOCATION_ROLE_MISMATCH';
    end if;
    if v_quantity <= 0 or not exists (
      select 1 from public.products where id = v_product_id and is_active
    ) then
      raise exception using errcode = 'P0001', message = 'INVALID_RETURN_LINE';
    end if;

    insert into public.inventory_document_lines (
      document_id, product_id, quantity, notes, sales_return_line_id, condition_snapshot
    ) values (
      v_document_id, v_product_id, v_quantity,
      'Condicion: ' || v_condition, (v_line->>'sales_return_line_id')::uuid, v_condition
    ) returning id into v_doc_line_id;

    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      notes, actor_name, device_name, device_identifier, document_id, document_line_id
    ) values (
      v_product_id, v_location.warehouse_id, v_location.id,
      extensions.gen_random_uuid(), v_quantity, 'RETURN',
      'Devolucion ' || p_return_number || ' · ' || v_condition,
      p_actor_name, p_device_name, p_device_identifier, v_document_id, v_doc_line_id
    );
  end loop;
  return v_document_id;
end;
$$;

revoke all on function public.inventory_receive_sales_return(uuid, uuid, text, jsonb, text, text, text)
  from public, anon, authenticated;
grant execute on function public.inventory_receive_sales_return(uuid, uuid, text, jsonb, text, text, text)
  to anon, authenticated;

create or replace function public.payments_settle_sales_return(
  p_command_id uuid,
  p_return_id uuid,
  p_invoice_id uuid,
  p_customer_id uuid,
  p_customer_name text,
  p_currency_code char(3),
  p_amount numeric,
  p_resolution text,
  p_reason text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_payload_hash bytea := extensions.digest(convert_to(jsonb_build_object(
    'return_id', p_return_id, 'invoice_id', p_invoice_id,
    'customer_id', p_customer_id, 'currency_code', p_currency_code,
    'amount', p_amount, 'resolution', p_resolution, 'reason', p_reason
  )::text, 'UTF8'), 'sha256');
  v_settlement public.payment_return_settlements%rowtype;
  v_effect_id uuid;
  v_paid numeric(18,2);
  v_refunded numeric(18,2);
  v_payment record;
begin
  if p_command_id is null or p_return_id is null or p_amount <= 0
     or p_resolution not in ('REFUND', 'CUSTOMER_CREDIT') then
    raise exception using errcode = 'P0001', message = 'INVALID_SETTLEMENT';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_command_id::text, 0));
  select * into v_settlement from public.payment_return_settlements
   where command_id = p_command_id or sales_return_id = p_return_id;
  if found then
    if v_settlement.command_id <> p_command_id or v_settlement.payload_hash <> v_payload_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_ID_CONFLICT';
    end if;
    return v_settlement.id;
  end if;

  -- Lock applied payments in stable order so parallel returns cannot spend the
  -- same received amount twice.
  for v_payment in
    select p.id
      from public.payment_applications pa
      join public.payments p on p.id = pa.payment_id
     where pa.invoice_id = p_invoice_id and p.status in ('CONFIRMED', 'REFUNDED')
     order by p.id for update of p
  loop null; end loop;

  select coalesce(sum(pa.amount_applied), 0)::numeric(18,2)
    into v_paid
    from public.payment_applications pa
    join public.payments p on p.id = pa.payment_id
   where pa.invoice_id = p_invoice_id and p.status in ('CONFIRMED', 'REFUNDED')
     and coalesce(pa.currency_code, p.currency_code) = p_currency_code;
  select coalesce(sum(r.amount), 0)::numeric(18,2)
    into v_refunded
    from public.refunds r
    join public.payments p on p.id = r.payment_id
    join public.payment_applications pa on pa.payment_id = p.id
   where pa.invoice_id = p_invoice_id and r.status <> 'REJECTED'
     and r.currency_code = p_currency_code;
  if v_paid - v_refunded < p_amount then
    raise exception using errcode = 'P0001', message = 'RETURN_FINANCIAL_CAPACITY_EXCEEDED';
  end if;

  insert into public.payment_return_settlements (
    command_id, payload_hash, sales_return_id, invoice_id, customer_id,
    currency_code, amount, resolution
  ) values (
    p_command_id, v_payload_hash, p_return_id, p_invoice_id, p_customer_id,
    p_currency_code, p_amount, p_resolution
  ) returning * into v_settlement;

  if p_resolution = 'REFUND' then
    for v_payment in
      select p.id, p.currency_code, sum(pa.amount_applied)::numeric(18,2) as applied
        from public.payment_applications pa
        join public.payments p on p.id = pa.payment_id
       where pa.invoice_id = p_invoice_id and p.status in ('CONFIRMED', 'REFUNDED')
         and p.currency_code = p_currency_code
       group by p.id, p.currency_code order by p.id
    loop
      exit when p_amount <= 0;
      declare
        v_available numeric(18,2);
        v_piece numeric(18,2);
      begin
        select greatest(v_payment.applied - coalesce(sum(r.amount), 0), 0)::numeric(18,2)
          into v_available from public.refunds r
         where r.payment_id = v_payment.id and r.status <> 'REJECTED';
        v_piece := least(p_amount, v_available);
        if v_piece > 0 then
          insert into public.refunds (
            payment_id, amount, currency_code, reason, status, created_by,
            created_device_name, created_device_identifier, sales_return_id,
            invoice_id, command_id
          ) values (
            v_payment.id, v_piece, p_currency_code, p_reason, 'PENDING',
            p_actor_name, p_device_name, p_device_identifier,
            p_return_id, p_invoice_id, extensions.gen_random_uuid()
          ) returning id into v_effect_id;
          p_amount := p_amount - v_piece;
        end if;
      end;
    end loop;
    if p_amount <> 0 then
      raise exception using errcode = 'P0001', message = 'REFUND_CAPACITY_EXCEEDED';
    end if;
  else
    insert into public.customer_credit_entries (
      customer_id, customer_name, entry_type, amount, currency_code, notes,
      created_by, created_device_name, created_device_identifier,
      sales_return_id, invoice_id, command_id
    ) values (
      p_customer_id, p_customer_name, 'CREDIT_NOTE', p_amount,
      p_currency_code, p_reason, p_actor_name, p_device_name,
      p_device_identifier, p_return_id, p_invoice_id, p_command_id
    ) returning id into v_effect_id;
  end if;
  return v_settlement.id;
end;
$$;

revoke all on function public.payments_settle_sales_return(uuid, uuid, uuid, uuid, text, char, numeric, text, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.payments_settle_sales_return(uuid, uuid, uuid, uuid, text, char, numeric, text, text, text, text, text)
  to anon, authenticated;

create or replace function public.sales_preview_return(p_invoice_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_invoice public.sales_invoices%rowtype;
  v_outstanding numeric(18,2);
  v_paid numeric(18,2);
  v_lines jsonb;
begin
  select * into v_invoice from public.sales_invoices where id = p_invoice_id;
  if not found or v_invoice.status not in ('CONFIRMED', 'PAID') then
    raise exception using errcode = 'P0001', message = 'INVOICE_NOT_RETURNABLE';
  end if;
  if v_invoice.customer_id is null then
    raise exception using errcode = 'P0001', message = 'INVOICE_CUSTOMER_MISSING';
  end if;
  select coalesce(sum(pa.amount_applied), 0)::numeric(18,2) into v_paid
    from public.payment_applications pa join public.payments p on p.id = pa.payment_id
   where pa.invoice_id = p_invoice_id and p.status in ('CONFIRMED', 'REFUNDED')
     and coalesce(pa.currency_code, p.currency_code) = v_invoice.currency_code;
  v_outstanding := greatest(v_invoice.total_amount - v_paid, 0);
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', il.id, 'product_id', il.product_id, 'quantity', il.quantity,
    'unit_price', il.unit_price, 'discount_percent', il.discount_percent,
    'total_price', il.total_price, 'product_sku', il.product_sku,
    'product_name', il.product_name,
    'original_net_unit_price', round(il.total_price / il.quantity, 4),
    'available_quantity', case when exists (
      select 1 from public.sales_return_lines rl
      join public.sales_returns r on r.id = rl.return_id
      where rl.invoice_line_id = il.id and r.status <> 'CANCELLED'
    ) then 0 else il.quantity end
  ) order by il.id), '[]'::jsonb) into v_lines
    from public.sales_invoice_lines il where il.invoice_id = p_invoice_id;
  return jsonb_build_object(
    'invoice_id', v_invoice.id, 'invoice_number', v_invoice.invoice_number,
    'customer_id', v_invoice.customer_id, 'customer_name', v_invoice.customer_name,
    'currency_code', v_invoice.currency_code, 'total_amount', v_invoice.total_amount,
    'paid_amount', v_paid, 'outstanding_amount', v_outstanding,
    'lines', v_lines,
    'sellable_locations', (select coalesce(jsonb_agg(jsonb_build_object(
      'id', l.id, 'warehouse_id', l.warehouse_id, 'code', l.code, 'name', l.name
    ) order by l.name), '[]'::jsonb) from public.inventory_locations l
      where l.is_active and l.stock_role = 'SELLABLE'),
    'quarantine_locations', (select coalesce(jsonb_agg(jsonb_build_object(
      'id', l.id, 'warehouse_id', l.warehouse_id, 'code', l.code, 'name', l.name
    ) order by l.name), '[]'::jsonb) from public.inventory_locations l
      where l.is_active and l.stock_role = 'QUARANTINE')
  );
end;
$$;

create or replace function public.sales_confirm_return(
  p_command_id uuid,
  p_invoice_id uuid,
  p_reason text,
  p_lines jsonb,
  p_resolution text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_returns
language plpgsql security definer set search_path = '' as $$
declare
  v_hash bytea;
  v_existing public.sales_returns%rowtype;
  v_return public.sales_returns%rowtype;
  v_invoice public.sales_invoices%rowtype;
  v_line jsonb;
  v_invoice_line public.sales_invoice_lines%rowtype;
  v_location public.inventory_locations%rowtype;
  v_quantity integer;
  v_price numeric(18,4);
  v_line_total numeric(18,2);
  v_return_line_id uuid;
  v_total numeric(18,2) := 0;
  v_paid numeric(18,2);
  v_outstanding numeric(18,2);
  v_debt_reduction numeric(18,2);
  v_excess numeric(18,2);
  v_inventory_id uuid;
  v_payment_effect_id uuid;
  v_inventory_lines jsonb := '[]'::jsonb;
  v_return_lines jsonb;
begin
  if p_command_id is null or p_invoice_id is null or length(btrim(coalesce(p_reason, ''))) not between 1 and 500
     or p_resolution not in ('REFUND', 'CUSTOMER_CREDIT')
     or jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  v_hash := extensions.digest(convert_to(jsonb_build_object(
    'invoice_id', p_invoice_id, 'reason', btrim(p_reason),
    'lines', p_lines, 'resolution', p_resolution
  )::text, 'UTF8'), 'sha256');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_command_id::text, 0));
  select * into v_existing from public.sales_returns where command_id = p_command_id for update;
  if found then
    if (select payload_hash from public.sales_return_commands where command_id = p_command_id) <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_ID_CONFLICT';
    end if;
    return v_existing;
  end if;

  select * into v_invoice from public.sales_invoices where id = p_invoice_id for update;
  if not found or v_invoice.status not in ('CONFIRMED', 'PAID') then
    raise exception using errcode = 'P0001', message = 'INVOICE_NOT_RETURNABLE';
  end if;
  if v_invoice.customer_id is null then
    raise exception using errcode = 'P0001', message = 'INVOICE_CUSTOMER_MISSING';
  end if;
  select * into v_existing from public.sales_returns where command_id = p_command_id for update;
  if found then
    if (select payload_hash from public.sales_return_commands where command_id = p_command_id) <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_ID_CONFLICT';
    end if;
    return v_existing;
  end if;
  if exists (select 1 from public.sales_return_commands where command_id = p_command_id) then
    raise exception using errcode = 'P0001', message = 'COMMAND_ID_CONFLICT';
  end if;

  for v_line in select value from jsonb_array_elements(p_lines) order by value->>'invoice_line_id' loop
    if (v_line->>'quantity') !~ '^[1-9][0-9]*$' then
      raise exception using errcode = 'P0001', message = 'RETURN_QUANTITY_INVALID';
    end if;
    v_quantity := (v_line->>'quantity')::integer;
    select * into v_invoice_line from public.sales_invoice_lines
      where id = (v_line->>'invoice_line_id')::uuid and invoice_id = p_invoice_id for update;
    if not found then
      raise exception using errcode = 'P0001', message = 'RETURN_LINE_NOT_IN_INVOICE';
    end if;
    if exists (select 1 from public.sales_return_lines rl join public.sales_returns r on r.id = rl.return_id
      where rl.invoice_line_id = v_invoice_line.id and r.status <> 'CANCELLED') then
      raise exception using errcode = 'P0001', message = 'RETURN_QUANTITY_EXCEEDED';
    end if;
    if v_quantity <> v_invoice_line.quantity then
      raise exception using errcode = 'P0001', message = 'RETURN_QUANTITY_EXCEEDED';
    end if;
    if (v_line->>'product_id')::uuid <> v_invoice_line.product_id then
      raise exception using errcode = 'P0001', message = 'RETURN_LINE_NOT_IN_INVOICE';
    end if;
    if v_line->>'condition' not in ('GOOD', 'DAMAGED') then
      raise exception using errcode = 'P0001', message = 'INVALID_RETURN_CONDITION';
    end if;
    select * into v_location from public.inventory_locations where id = (v_line->>'location_id')::uuid and is_active;
    if not found or (v_line->>'condition' = 'GOOD' and v_location.stock_role <> 'SELLABLE')
       or (v_line->>'condition' = 'DAMAGED' and v_location.stock_role <> 'QUARANTINE') then
      raise exception using errcode = 'P0001', message = 'LOCATION_ROLE_MISMATCH';
    end if;
    v_price := round(v_invoice_line.total_price / v_invoice_line.quantity, 4);
    v_line_total := v_invoice_line.total_price;
    v_total := v_total + v_line_total;
    v_return_lines := coalesce(v_return_lines, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
      'invoice_line_id', v_invoice_line.id, 'product_id', v_invoice_line.product_id,
      'quantity', v_quantity, 'unit_price', v_price, 'total_price', v_line_total,
      'product_sku', v_invoice_line.product_sku, 'product_name', v_invoice_line.product_name,
      'condition', v_line->>'condition', 'location_id', v_location.id
    ));
    v_inventory_lines := v_inventory_lines || jsonb_build_array(jsonb_build_object(
      'sales_return_line_id', null, 'invoice_line_id', v_invoice_line.id,
      'product_id', v_invoice_line.product_id, 'quantity', v_quantity,
      'condition', v_line->>'condition', 'location_id', v_location.id
    ));
  end loop;

  insert into public.sales_returns (
    return_number, invoice_id, customer_id, customer_name, status, total_amount,
    currency_code, reason, command_id, created_by, created_device_name,
    created_device_identifier, confirmed_at, financial_resolution
  ) values (
    'DEV-' || lpad(nextval('public.return_number_seq')::text, 6, '0'),
    p_invoice_id, v_invoice.customer_id, v_invoice.customer_name, 'CONFIRMED',
    v_total, v_invoice.currency_code, btrim(p_reason), p_command_id,
    p_actor_name, p_device_name, p_device_identifier, now(), p_resolution
  ) returning * into v_return;

  insert into public.sales_return_commands(command_id, payload_hash, entity_id)
    values (p_command_id, v_hash, v_return.id);

  for v_line in select value from jsonb_array_elements(v_return_lines) loop
    insert into public.sales_return_lines (
      return_id, invoice_line_id, product_id, quantity, unit_price, total_price,
      product_sku, product_name, condition, inventory_location_id, original_net_unit_price
    ) values (
      v_return.id, (v_line->>'invoice_line_id')::uuid, (v_line->>'product_id')::uuid,
      (v_line->>'quantity')::integer, (v_line->>'unit_price')::numeric,
      (v_line->>'total_price')::numeric, v_line->>'product_sku', v_line->>'product_name',
      v_line->>'condition', (v_line->>'location_id')::uuid, (v_line->>'unit_price')::numeric
    ) returning id into v_return_line_id;
    v_inventory_lines := jsonb_set(v_inventory_lines,
      array[(select (count(*) - 1)::text from public.sales_return_lines where return_id = v_return.id), 'sales_return_line_id'],
      to_jsonb(v_return_line_id), true);
  end loop;

  select coalesce(sum(pa.amount_applied), 0)::numeric(18,2) into v_paid
    from public.payment_applications pa join public.payments p on p.id = pa.payment_id
   where pa.invoice_id = p_invoice_id and p.status in ('CONFIRMED', 'REFUNDED')
     and coalesce(pa.currency_code, p.currency_code) = v_invoice.currency_code;
  v_outstanding := greatest(v_invoice.total_amount - v_paid, 0);
  v_debt_reduction := least(v_total, v_outstanding);
  v_excess := v_total - v_debt_reduction;

  if v_excess > 0 then
    v_payment_effect_id := public.payments_settle_sales_return(
      extensions.gen_random_uuid(), v_return.id, v_invoice.id, v_invoice.customer_id,
      v_invoice.customer_name, v_invoice.currency_code, v_excess, p_resolution,
      btrim(p_reason), p_actor_name, p_device_name, p_device_identifier
    );
  end if;

  v_inventory_id := public.inventory_receive_sales_return(
    extensions.gen_random_uuid(), v_return.id, v_return.return_number,
    v_inventory_lines, p_actor_name, p_device_name, p_device_identifier
  );
  update public.sales_returns set inventory_document_id = v_inventory_id,
    debt_reduction_amount = v_debt_reduction,
    financial_resolution_amount = v_excess, payment_effect_id = v_payment_effect_id
   where id = v_return.id returning * into v_return;
  perform public.audit_payments('sales', 'sales_returns', v_return.id, 'CONFIRM',
    p_actor_name, p_device_name, p_device_identifier, 'return', null,
    jsonb_build_object('invoice_id', p_invoice_id, 'amount', v_total,
      'debt_reduction', v_debt_reduction, 'resolution', p_resolution,
      'resolution_amount', v_excess, 'inventory_document_id', v_inventory_id)::text);
  return v_return;
end;
$$;

revoke all on function public.sales_preview_return(uuid) from public;
grant execute on function public.sales_preview_return(uuid) to anon, authenticated;
revoke all on function public.sales_confirm_return(uuid, uuid, text, jsonb, text, text, text, text)
  from public, anon;
grant execute on function public.sales_confirm_return(uuid, uuid, text, jsonb, text, text, text, text)
  to authenticated;

create table if not exists public.sales_return_commands (
  command_id uuid primary key,
  payload_hash bytea not null,
  entity_id uuid references public.sales_returns(id) on delete restrict,
  created_at timestamptz not null default now()
);
alter table public.sales_return_commands enable row level security;
revoke all on public.sales_return_commands from public, anon, authenticated;
