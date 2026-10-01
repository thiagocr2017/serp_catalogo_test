-- Inventario Avanzado: Reservas, Conteos Físicos y Transferencias Diferidas

-- ============================================================
-- 1. RESERVAS
-- ============================================================

create table if not exists public.inventory_reservations (
  id uuid primary key default extensions.gen_random_uuid(),
  product_id uuid not null references public.products(id),
  location_id uuid not null references public.inventory_locations(id),
  order_id text not null,
  quantity integer not null check (quantity > 0),
  status text not null default 'PENDING' check (status in ('PENDING', 'RELEASED', 'CONSUMED')),
  command_id uuid not null unique,
  created_by text,
  created_device_name text,
  created_device_identifier text,
  created_at timestamptz not null default now(),
  released_at timestamptz
);

alter table public.inventory_reservations enable row level security;
revoke all on public.inventory_reservations from public, anon, authenticated;
grant select on public.inventory_reservations to anon, authenticated;

-- Columna de reservado en balances
alter table public.inventory_balances
  add column if not exists reserved_quantity integer not null default 0;

-- RPC: reserve_inventory
create or replace function public.reserve_inventory(
  p_command_id uuid,
  p_product_id uuid,
  p_location_id uuid,
  p_order_id text,
  p_quantity integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.inventory_reservations
language plpgsql security invoker set search_path = '' as $$
declare
  v_reservation public.inventory_reservations%rowtype;
  v_available integer;
begin
  if p_quantity <= 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  select quantity - reserved_quantity into v_available
  from public.inventory_balances
  where product_id = p_product_id and location_id = p_location_id
  for update;

  if v_available is null or v_available < p_quantity then
    raise exception using errcode = 'P0001', message = 'INSUFFICIENT_STOCK';
  end if;

  insert into public.inventory_reservations (
    product_id, location_id, order_id, quantity, command_id,
    created_by, created_device_name, created_device_identifier
  ) values (
    p_product_id, p_location_id, p_order_id, p_quantity, p_command_id,
    p_actor_name, p_device_name, p_device_identifier
  ) on conflict (command_id) do nothing
  returning * into v_reservation;

  if not found then
    select * into v_reservation from public.inventory_reservations where command_id = p_command_id;
    return v_reservation;
  end if;

  update public.inventory_balances
  set reserved_quantity = reserved_quantity + p_quantity
  where product_id = p_product_id and location_id = p_location_id;

  return v_reservation;
end;
$$;

revoke all on function public.reserve_inventory(uuid, uuid, uuid, text, integer, text, text, text) from public;
grant execute on function public.reserve_inventory(uuid, uuid, uuid, text, integer, text, text, text) to anon, authenticated;

-- RPC: release_reservation
create or replace function public.release_reservation(
  p_reservation_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  v_reservation public.inventory_reservations%rowtype;
begin
  select * into v_reservation from public.inventory_reservations
  where id = p_reservation_id and status = 'PENDING' for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'RESERVATION_NOT_FOUND';
  end if;

  update public.inventory_reservations
  set status = 'RELEASED', released_at = now()
  where id = p_reservation_id;

  update public.inventory_balances
  set reserved_quantity = reserved_quantity - v_reservation.quantity
  where product_id = v_reservation.product_id and location_id = v_reservation.location_id;
end;
$$;

revoke all on function public.release_reservation(uuid, text, text, text) from public;
grant execute on function public.release_reservation(uuid, text, text, text) to anon, authenticated;

-- RPC: consume_reservation (libera reserva y crea movimiento SALE)
create or replace function public.consume_reservation(
  p_reservation_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  v_reservation public.inventory_reservations%rowtype;
begin
  select * into v_reservation from public.inventory_reservations
  where id = p_reservation_id and status = 'PENDING' for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'RESERVATION_NOT_FOUND';
  end if;

  update public.inventory_reservations
  set status = 'CONSUMED'
  where id = p_reservation_id;

  update public.inventory_balances
  set reserved_quantity = reserved_quantity - v_reservation.quantity,
      quantity = quantity - v_reservation.quantity
  where product_id = v_reservation.product_id and location_id = v_reservation.location_id;

  update public.products
  set current_stock = current_stock - v_reservation.quantity
  where id = v_reservation.product_id;
end;
$$;

revoke all on function public.consume_reservation(uuid, text, text, text) from public;
grant execute on function public.consume_reservation(uuid, text, text, text) to anon, authenticated;

-- ============================================================
-- 2. CONTOS FÍSICOS
-- ============================================================

create table if not exists public.inventory_counts (
  id uuid primary key default extensions.gen_random_uuid(),
  warehouse_id uuid not null references public.warehouses(id),
  status text not null default 'DRAFT' check (status in ('DRAFT', 'COUNTING', 'REVIEW', 'CONFIRMED', 'CANCELLED')),
  created_by text,
  created_device_name text,
  created_device_identifier text,
  created_at timestamptz not null default now(),
  confirmed_at timestamptz
);

create table if not exists public.inventory_count_lines (
  id uuid primary key default extensions.gen_random_uuid(),
  count_id uuid not null references public.inventory_counts(id) on delete cascade,
  product_id uuid not null references public.products(id),
  location_id uuid references public.inventory_locations(id),
  expected_quantity integer,
  counted_quantity integer,
  difference integer,
  reviewed boolean not null default false,
  justification text
);

alter table public.inventory_counts enable row level security;
alter table public.inventory_count_lines enable row level security;
revoke all on public.inventory_counts from public, anon, authenticated;
revoke all on public.inventory_count_lines from public, anon, authenticated;
grant select on public.inventory_counts to anon, authenticated;
grant select on public.inventory_count_lines to anon, authenticated;

-- RPC: create_inventory_count
create or replace function public.create_inventory_count(
  p_warehouse_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.inventory_counts
language plpgsql security invoker set search_path = '' as $$
declare
  v_id uuid;
begin
  insert into public.inventory_counts (warehouse_id, status, created_by, created_device_name, created_device_identifier)
  values (p_warehouse_id, 'DRAFT', p_actor_name, p_device_name, p_device_identifier)
  returning id into v_id;
  return (select * from public.inventory_counts where id = v_id);
end;
$$;

revoke all on function public.create_inventory_count(uuid, text, text, text) from public;
grant execute on function public.create_inventory_count(uuid, text, text, text) to anon, authenticated;

-- RPC: confirm_count_and_adjust
create or replace function public.confirm_count_and_adjust(
  p_count_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  v_line public.inventory_count_lines%rowtype;
  v_location_id uuid;
begin
  update public.inventory_counts set status = 'CONFIRMED', confirmed_at = now()
  where id = p_count_id and status = 'REVIEW';

  if not found then
    raise exception using errcode = 'P0001', message = 'COUNT_NOT_REVIEWABLE';
  end if;

  for v_line in
    select * from public.inventory_count_lines
    where count_id = p_count_id and difference <> 0 and reviewed
  loop
    select id into v_location_id from public.inventory_locations
    where warehouse_id = (select warehouse_id from public.inventory_counts where id = p_count_id)
      and is_default limit 1;

    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier
    ) values (
      v_line.product_id,
      (select warehouse_id from public.inventory_counts where id = p_count_id),
      coalesce(v_line.location_id, v_location_id),
      extensions.gen_random_uuid(),
      v_line.difference,
      'ADJUSTMENT',
      p_actor_name, p_device_name, p_device_identifier
    );
  end loop;
end;
$$;

revoke all on function public.confirm_count_and_adjust(uuid, text, text, text) from public;
grant execute on function public.confirm_count_and_adjust(uuid, text, text, text) to anon, authenticated;

-- ============================================================
-- 3. TRANSFERENCIAS DIFERIDAS
-- ============================================================

-- Nuevos estados para transferencias
alter type public.inventory_document_status add value if not exists 'BORRADOR';
alter type public.inventory_document_status add value if not exists 'DESPACHADA';
alter type public.inventory_document_status add value if not exists 'EN_TRANSITO';
alter type public.inventory_document_status add value if not exists 'RECIBIDA';

-- RPC: dispatch_transfer
create or replace function public.dispatch_transfer(
  p_document_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  update public.inventory_documents set status = 'DESPACHADA'
  where id = p_document_id and status = 'BORRADOR';
  if not found then
    raise exception using errcode = 'P0001', message = 'TRANSFER_NOT_DRAFT';
  end if;
end;
$$;

revoke all on function public.dispatch_transfer(uuid, text, text, text) from public;
grant execute on function public.dispatch_transfer(uuid, text, text, text) to anon, authenticated;

-- RPC: mark_transfer_in_transit
create or replace function public.mark_transfer_in_transit(
  p_document_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  update public.inventory_documents set status = 'EN_TRANSITO'
  where id = p_document_id and status = 'DESPACHADA';
  if not found then
    raise exception using errcode = 'P0001', message = 'TRANSFER_NOT_DISPATCHED';
  end if;
end;
$$;

revoke all on function public.mark_transfer_in_transit(uuid, text, text, text) from public;
grant execute on function public.mark_transfer_in_transit(uuid, text, text, text) to anon, authenticated;

-- RPC: receive_transfer
create or replace function public.receive_transfer(
  p_document_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  v_line public.inventory_document_lines%rowtype;
begin
  update public.inventory_documents set status = 'RECIBIDA'
  where id = p_document_id and status = 'EN_TRANSITO';
  if not found then
    raise exception using errcode = 'P0001', message = 'TRANSFER_NOT_IN_TRANSIT';
  end if;

  for v_line in
    select * from public.inventory_document_lines where document_id = p_document_id
  loop
    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier, document_id
    ) values (
      v_line.product_id,
      (select destination_warehouse_id from public.inventory_documents where id = p_document_id),
      (select destination_location_id from public.inventory_documents where id = p_document_id),
      extensions.gen_random_uuid(),
      v_line.quantity,
      'TRANSFER_IN',
      p_actor_name, p_device_name, p_device_identifier,
      p_document_id
    );
  end loop;
end;
$$;

revoke all on function public.receive_transfer(uuid, text, text, text) from public;
grant execute on function public.receive_transfer(uuid, text, text, text) to anon, authenticated;
