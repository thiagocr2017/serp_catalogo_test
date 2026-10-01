-- Módulo 4: Pagos y Recibos — Fundaciones
-- Crea las tablas, RPCs idempotentes y políticas de seguridad.

-- ============================================================
-- 1. TABLAS
-- ============================================================

-- Métodos de pago dinámicos
create table if not exists public.payment_methods (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  is_active boolean not null default true,
  created_by text,
  created_device_name text,
  created_device_identifier text,
  updated_by text,
  updated_device_name text,
  updated_device_identifier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

-- Cuentas monetarias de la empresa
create table if not exists public.money_accounts (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  account_type text not null check (account_type in ('CASH', 'BANK', 'VAULT', 'PENDING_DEPOSITS', 'OTHER')),
  currency_code char(3) not null default 'USD',
  is_active boolean not null default true,
  created_by text,
  created_device_name text,
  created_device_identifier text,
  updated_by text,
  updated_device_name text,
  updated_device_identifier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

-- Pagos
create table if not exists public.payments (
  id uuid primary key default extensions.gen_random_uuid(),
  receipt_number text unique,
  status text not null check (status in ('PENDING', 'CONFIRMED', 'CANCELLED', 'REFUNDED')),
  customer_name text,
  customer_id uuid,
  total_amount numeric(18,2) not null default 0,
  currency_code char(3) not null default 'USD',
  exchange_rate numeric(18,6) not null default 1,
  notes text,
  created_by text,
  created_device_name text,
  created_device_identifier text,
  updated_by text,
  updated_device_name text,
  updated_device_identifier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

-- Componentes de pago (un pago puede combinar varios métodos/monedas)
create table if not exists public.payment_components (
  id uuid primary key default extensions.gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  method_id uuid references public.payment_methods(id),
  money_account_id uuid references public.money_accounts(id),
  currency_code char(3) not null,
  original_amount numeric(18,2) not null,
  exchange_rate numeric(18,6) not null default 1,
  usd_equivalent numeric(18,2) not null,
  reference text,
  created_at timestamptz not null default now()
);

-- Aplicaciones de pago a facturas
create table if not exists public.payment_applications (
  id uuid primary key default extensions.gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  invoice_id uuid not null,
  amount_applied numeric(18,2) not null,
  created_at timestamptz not null default now()
);

-- Entradas de crédito del cliente
create table if not exists public.customer_credit_entries (
  id uuid primary key default extensions.gen_random_uuid(),
  customer_id uuid not null,
  customer_name text not null,
  entry_type text not null check (entry_type in ('ADVANCE', 'CREDIT_NOTE', 'REFUND')),
  amount numeric(18,2) not null,
  currency_code char(3) not null default 'USD',
  payment_id uuid references public.payments(id),
  notes text,
  created_by text,
  created_device_name text,
  created_device_identifier text,
  created_at timestamptz not null default now()
);

-- Reembolsos
create table if not exists public.refunds (
  id uuid primary key default extensions.gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  amount numeric(18,2) not null,
  currency_code char(3) not null default 'USD',
  reason text not null,
  status text not null default 'PENDING' check (status in ('PENDING', 'CONFIRMED', 'REJECTED')),
  created_by text,
  created_device_name text,
  created_device_identifier text,
  created_at timestamptz not null default now()
);

-- Gastos
create table if not exists public.expenses (
  id uuid primary key default extensions.gen_random_uuid(),
  concept text not null,
  beneficiary text,
  amount numeric(18,2) not null,
  currency_code char(3) not null default 'USD',
  money_account_id uuid references public.money_accounts(id),
  expense_date date not null default current_date,
  created_by text,
  created_device_name text,
  created_device_identifier text,
  created_at timestamptz not null default now()
);

-- Movimientos entre cuentas
create table if not exists public.money_account_transactions (
  id uuid primary key default extensions.gen_random_uuid(),
  from_account_id uuid references public.money_accounts(id),
  to_account_id uuid references public.money_accounts(id),
  amount numeric(18,2) not null,
  currency_code char(3) not null default 'USD',
  exchange_rate numeric(18,6) not null default 1,
  notes text,
  created_by text,
  created_device_name text,
  created_device_identifier text,
  created_at timestamptz not null default now()
);

-- Depósitos sin identificar
create table if not exists public.unidentified_deposits (
  id uuid primary key default extensions.gen_random_uuid(),
  amount numeric(18,2) not null,
  currency_code char(3) not null default 'USD',
  money_account_id uuid references public.money_accounts(id),
  deposit_date date not null default current_date,
  notes text,
  identified boolean not null default false,
  payment_id uuid references public.payments(id),
  created_by text,
  created_device_name text,
  created_device_identifier text,
  created_at timestamptz not null default now()
);

-- Tablas de idempotencia
create table if not exists public.payment_commands (
  command_id uuid primary key,
  payload_hash bytea not null,
  entity_id uuid,
  result_version integer,
  created_at timestamptz not null default now()
);

create table if not exists public.refund_commands (
  command_id uuid primary key,
  payload_hash bytea not null,
  entity_id uuid,
  created_at timestamptz not null default now()
);

-- ============================================================
-- 2. RLS Y PERMISOS
-- ============================================================

alter table public.payment_methods enable row level security;
alter table public.money_accounts enable row level security;
alter table public.payments enable row level security;
alter table public.payment_components enable row level security;
alter table public.payment_applications enable row level security;
alter table public.customer_credit_entries enable row level security;
alter table public.refunds enable row level security;
alter table public.expenses enable row level security;
alter table public.money_account_transactions enable row level security;
alter table public.unidentified_deposits enable row level security;
alter table public.payment_commands enable row level security;
alter table public.refund_commands enable row level security;

-- Revocar todo acceso directo
revoke all on public.payment_methods from public, anon, authenticated;
revoke all on public.money_accounts from public, anon, authenticated;
revoke all on public.payments from public, anon, authenticated;
revoke all on public.payment_components from public, anon, authenticated;
revoke all on public.payment_applications from public, anon, authenticated;
revoke all on public.customer_credit_entries from public, anon, authenticated;
revoke all on public.refunds from public, anon, authenticated;
revoke all on public.expenses from public, anon, authenticated;
revoke all on public.money_account_transactions from public, anon, authenticated;
revoke all on public.unidentified_deposits from public, anon, authenticated;
revoke all on public.payment_commands from public, anon, authenticated;
revoke all on public.refund_commands from public, anon, authenticated;

-- Solo SELECT para lecturas (los writes van por RPCs)
grant select on public.payment_methods to anon, authenticated;
grant select on public.money_accounts to anon, authenticated;
grant select on public.payments to anon, authenticated;
grant select on public.payment_components to anon, authenticated;
grant select on public.payment_applications to anon, authenticated;
grant select on public.customer_credit_entries to anon, authenticated;
grant select on public.refunds to anon, authenticated;
grant select on public.expenses to anon, authenticated;
grant select on public.money_account_transactions to anon, authenticated;
grant select on public.unidentified_deposits to anon, authenticated;

-- ============================================================
-- 3. FUNCIÓN DE AUDITORÍA PARA PAGOS
-- ============================================================

create or replace function public.audit_payments(
  p_module text,
  p_entity_type text,
  p_entity_id uuid,
  p_operation text,
  p_actor text,
  p_device text,
  p_identifier text,
  p_field text,
  p_old text,
  p_new text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_action uuid;
begin
  insert into public.audit_actions(module, entity_type, entity_id, operation, actor_name, device_name, device_identifier)
  values (p_module, p_entity_type, p_entity_id, p_operation, p_actor, p_device, p_identifier)
  returning id into v_action;
  insert into public.audit_logs(action_id, table_name, record_id, operation, field_name, old_value, new_value, actor_name, device_name, device_identifier)
  values (v_action, p_entity_type, p_entity_id, 'UPDATE', p_field, p_old, p_new, p_actor, p_device, p_identifier);
  return v_action;
end;
$$;

revoke all on function public.audit_payments(text, text, uuid, text, text, text, text, text, text, text) from public, anon, authenticated;

-- ============================================================
-- 4. RPC: create_payment_method
-- ============================================================

create or replace function public.create_payment_method(
  p_name text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.payment_methods
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.payment_methods (name, created_by, created_device_name, created_device_identifier)
  values (btrim(p_name), p_actor_name, p_device_name, p_device_identifier)
  returning id into v_id;
  return (select * from public.payment_methods where id = v_id);
end;
$$;

revoke all on function public.create_payment_method(text, text, text, text) from public;
grant execute on function public.create_payment_method(text, text, text, text) to anon, authenticated;

-- ============================================================
-- 5. RPC: create_money_account
-- ============================================================

create or replace function public.create_money_account(
  p_name text,
  p_account_type text,
  p_currency_code char(3),
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.money_accounts
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if p_account_type not in ('CASH', 'BANK', 'VAULT', 'PENDING_DEPOSITS', 'OTHER') then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.money_accounts (name, account_type, currency_code, created_by, created_device_name, created_device_identifier)
  values (btrim(p_name), p_account_type, p_currency_code, p_actor_name, p_device_name, p_device_identifier)
  returning id into v_id;
  return (select * from public.money_accounts where id = v_id);
end;
$$;

revoke all on function public.create_money_account(text, text, char, text, text, text) from public;
grant execute on function public.create_money_account(text, text, char, text, text, text) to anon, authenticated;

-- ============================================================
-- 6. RPC: create_payment (PENDING)
-- ============================================================

create or replace function public.create_payment(
  p_command_id uuid,
  p_customer_name text,
  p_total_amount numeric,
  p_currency_code char(3),
  p_exchange_rate numeric,
  p_notes text,
  p_components jsonb,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.payments
language plpgsql security definer set search_path = '' as $$
declare
  v_hash bytea := extensions.digest(convert_to(jsonb_build_object(
    'operation', 'create_payment',
    'customer_name', btrim(p_customer_name),
    'total_amount', p_total_amount,
    'currency_code', p_currency_code,
    'exchange_rate', p_exchange_rate,
    'components', p_components
  )::text, 'UTF8'), 'sha256');
  v_id uuid;
  v_payment public.payments%rowtype;
  v_component jsonb;
  v_method_id uuid;
  v_account_id uuid;
  v_component_currency char(3);
  v_original_amount numeric;
  v_component_rate numeric;
  v_usd_equivalent numeric;
begin
  -- Idempotencia
  insert into public.payment_commands(command_id, payload_hash)
  values (p_command_id, v_hash) on conflict do nothing returning command_id into v_id;
  if v_id is null then
    select entity_id into v_id from public.payment_commands where command_id = p_command_id for update;
    if (select payload_hash from public.payment_commands where command_id = p_command_id) <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_PAYLOAD_MISMATCH';
    end if;
    if v_id is null then
      raise exception using errcode = 'P0001', message = 'COMMAND_INCOMPLETE';
    end if;
    select * into v_payment from public.payments where id = v_id;
    return v_payment;
  end if;

  -- Validaciones
  if p_total_amount <= 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if jsonb_array_length(p_components) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  -- Insertar pago
  insert into public.payments (status, customer_name, total_amount, currency_code, exchange_rate, notes, created_by, created_device_name, created_device_identifier)
  values ('PENDING', btrim(p_customer_name), p_total_amount, p_currency_code, p_exchange_rate, p_notes, p_actor_name, p_device_name, p_device_identifier)
  returning * into v_payment;

  -- Insertar componentes
  for v_component in select * from jsonb_array_elements(p_components) loop
    v_method_id := (v_component->>'method_id')::uuid;
    v_account_id := (v_component->>'money_account_id')::uuid;
    v_component_currency := v_component->>'currency_code';
    v_original_amount := (v_component->>'original_amount')::numeric;
    v_component_rate := (v_component->>'exchange_rate')::numeric;
    v_usd_equivalent := (v_component->>'usd_equivalent')::numeric;

    insert into public.payment_components (payment_id, method_id, money_account_id, currency_code, original_amount, exchange_rate, usd_equivalent, reference)
    values (v_payment.id, v_method_id, v_account_id, v_component_currency, v_original_amount, v_component_rate, v_usd_equivalent, v_component->>'reference');
  end loop;

  -- Marcar comando completado
  update public.payment_commands set entity_id = v_payment.id where command_id = p_command_id;

  -- Auditoría
  perform public.audit_payments('payments', 'payments', v_payment.id, 'CREATE', p_actor_name, p_device_name, p_device_identifier, 'payment', null, v_payment.total_amount::text);

  return v_payment;
end;
$$;

revoke all on function public.create_payment(uuid, text, numeric, char, numeric, text, jsonb, text, text, text) from public;
grant execute on function public.create_payment(uuid, text, numeric, char, numeric, text, jsonb, text, text, text) to anon, authenticated;

-- ============================================================
-- 7. RPC: confirm_payment
-- ============================================================

create or replace function public.confirm_payment(
  p_payment_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.payments
language plpgsql security definer set search_path = '' as $$
declare
  v_payment public.payments%rowtype;
begin
  update public.payments
     set status = 'CONFIRMED',
         receipt_number = 'RC-' || lpad(nextval('payment_receipt_seq')::text, 6, '0'),
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_payment_id and status = 'PENDING'
  returning * into v_payment;
  if not found then
    raise exception using errcode = 'P0001', message = 'PAYMENT_NOT_PENDING';
  end if;
  perform public.audit_payments('payments', 'payments', v_payment.id, 'CONFIRM', p_actor_name, p_device_name, p_device_identifier, 'status', 'PENDING', 'CONFIRMED');
  return v_payment;
end;
$$;

-- Secuencia para numeración de recibos
create sequence if not exists payment_receipt_seq start 1;

revoke all on function public.confirm_payment(uuid, text, text, text) from public;
grant execute on function public.confirm_payment(uuid, text, text, text) to anon, authenticated;

-- ============================================================
-- 8. RPC: cancel_payment
-- ============================================================

create or replace function public.cancel_payment(
  p_payment_id uuid,
  p_reason text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.payments
language plpgsql security definer set search_path = '' as $$
declare
  v_payment public.payments%rowtype;
begin
  update public.payments
     set status = 'CANCELLED',
         notes = coalesce(notes, '') || ' [CANCELLED: ' || p_reason || ']',
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_payment_id and status in ('PENDING', 'CONFIRMED')
  returning * into v_payment;
  if not found then
    raise exception using errcode = 'P0001', message = 'PAYMENT_NOT_CANCELLABLE';
  end if;
  perform public.audit_payments('payments', 'payments', v_payment.id, 'CANCEL', p_actor_name, p_device_name, p_device_identifier, 'status', 'CONFIRMED', 'CANCELLED');
  return v_payment;
end;
$$;

revoke all on function public.cancel_payment(uuid, text, text, text, text) from public;
grant execute on function public.cancel_payment(uuid, text, text, text, text) to anon, authenticated;

-- ============================================================
-- 9. RPC: create_expense
-- ============================================================

create or replace function public.create_expense(
  p_concept text,
  p_beneficiary text,
  p_amount numeric,
  p_currency_code char(3),
  p_money_account_id uuid,
  p_expense_date date,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.expenses
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
begin
  if btrim(p_concept) = '' or p_amount <= 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.expenses (concept, beneficiary, amount, currency_code, money_account_id, expense_date, created_by, created_device_name, created_device_identifier)
  values (btrim(p_concept), p_beneficiary, p_amount, p_currency_code, p_money_account_id, p_expense_date, p_actor_name, p_device_name, p_device_identifier)
  returning id into v_id;
  perform public.audit_payments('payments', 'expenses', v_id, 'CREATE', p_actor_name, p_device_name, p_device_identifier, 'expense', null, p_amount::text);
  return (select * from public.expenses where id = v_id);
end;
$$;

revoke all on function public.create_expense(text, text, numeric, char, uuid, date, text, text, text) from public;
grant execute on function public.create_expense(text, text, numeric, char, uuid, date, text, text, text) to anon, authenticated;

-- ============================================================
-- 10. RPC: transfer_between_accounts
-- ============================================================

create or replace function public.transfer_between_accounts(
  p_from_account_id uuid,
  p_to_account_id uuid,
  p_amount numeric,
  p_currency_code char(3),
  p_exchange_rate numeric,
  p_notes text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_amount <= 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if p_from_account_id = p_to_account_id then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.money_account_transactions (from_account_id, to_account_id, amount, currency_code, exchange_rate, notes, created_by, created_device_name, created_device_identifier)
  values (p_from_account_id, p_to_account_id, p_amount, p_currency_code, p_exchange_rate, p_notes, p_actor_name, p_device_name, p_device_identifier);
  perform public.audit_payments('payments', 'money_account_transactions', p_from_account_id, 'TRANSFER', p_actor_name, p_device_name, p_device_identifier, 'transfer', null, p_amount::text);
end;
$$;

revoke all on function public.transfer_between_accounts(uuid, uuid, numeric, char, numeric, text, text, text, text) from public;
grant execute on function public.transfer_between_accounts(uuid, uuid, numeric, char, numeric, text, text, text, text) to anon, authenticated;
