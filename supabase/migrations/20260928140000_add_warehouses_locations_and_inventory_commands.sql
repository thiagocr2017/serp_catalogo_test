create table public.warehouses (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (length(trim(code)) > 0),
  name text not null check (length(trim(name)) > 0),
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  created_by text,
  updated_by text,
  created_device_name text,
  created_device_identifier text,
  updated_device_name text,
  updated_device_identifier text
);

create unique index one_default_warehouse_idx
  on public.warehouses (is_default) where is_default;

create table public.inventory_locations (
  id uuid primary key default gen_random_uuid(),
  warehouse_id uuid not null references public.warehouses(id),
  code text not null check (length(trim(code)) > 0),
  name text not null check (length(trim(name)) > 0),
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  created_by text,
  updated_by text,
  created_device_name text,
  created_device_identifier text,
  updated_device_name text,
  updated_device_identifier text,
  unique (warehouse_id, code),
  unique (id, warehouse_id)
);

create unique index one_default_location_per_warehouse_idx
  on public.inventory_locations (warehouse_id, is_default) where is_default;

insert into public.warehouses (id, code, name, is_default)
values ('30000000-0000-0000-0000-000000000001', 'PRINCIPAL', 'Bodega principal', true);

insert into public.inventory_locations (id, warehouse_id, code, name, is_default)
values (
  '31000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',
  'GENERAL',
  'Ubicación general',
  true
);

alter table public.inventory_transactions
  add column warehouse_id uuid references public.warehouses(id),
  add column location_id uuid references public.inventory_locations(id),
  add column command_id uuid;

alter table public.inventory_transactions
  disable trigger inventory_transactions_no_update_or_delete;

update public.inventory_transactions
set warehouse_id = '30000000-0000-0000-0000-000000000001',
    location_id = '31000000-0000-0000-0000-000000000001',
    command_id = id;

alter table public.inventory_transactions
  enable trigger inventory_transactions_no_update_or_delete;

alter table public.inventory_transactions
  alter column warehouse_id set not null,
  alter column location_id set not null,
  alter column command_id set not null,
  add constraint inventory_transaction_location_warehouse_fk
    foreign key (location_id, warehouse_id)
    references public.inventory_locations(id, warehouse_id);

create unique index inventory_transactions_command_id_idx
  on public.inventory_transactions(command_id);
create index inventory_transactions_location_created_idx
  on public.inventory_transactions(location_id, created_at desc);

create table public.inventory_balances (
  product_id uuid not null references public.products(id),
  warehouse_id uuid not null references public.warehouses(id),
  location_id uuid not null references public.inventory_locations(id),
  quantity integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (product_id, location_id),
  foreign key (location_id, warehouse_id)
    references public.inventory_locations(id, warehouse_id)
);

insert into public.inventory_balances (product_id, warehouse_id, location_id, quantity)
select id,
       '30000000-0000-0000-0000-000000000001',
       '31000000-0000-0000-0000-000000000001',
       current_stock
from public.products;

create or replace function public.apply_inventory_transaction()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  insert into public.inventory_balances (
    product_id, warehouse_id, location_id, quantity, updated_at
  ) values (
    new.product_id, new.warehouse_id, new.location_id, new.quantity, now()
  )
  on conflict (product_id, location_id) do update
    set quantity = public.inventory_balances.quantity + excluded.quantity,
        warehouse_id = excluded.warehouse_id,
        updated_at = now();

  update public.products
     set current_stock = current_stock + new.quantity,
         updated_by = coalesce(new.actor_name, 'device:' || new.device_identifier),
         updated_device_name = new.device_name,
         updated_device_identifier = new.device_identifier
   where id = new.product_id;

  if not found then
    raise exception 'El producto % no existe', new.product_id;
  end if;

  return new;
end;
$$;

create or replace function public.record_inventory_transaction(
  p_command_id uuid,
  p_product_id uuid,
  p_location_id uuid,
  p_quantity integer,
  p_reason public.inventory_transaction_reason,
  p_notes text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
)
returns public.inventory_transactions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  existing_transaction public.inventory_transactions;
  selected_warehouse_id uuid;
  created_transaction public.inventory_transactions;
begin
  select * into existing_transaction
  from public.inventory_transactions
  where command_id = p_command_id;

  if found then
    return existing_transaction;
  end if;

  if p_quantity = 0 then
    raise exception 'La cantidad debe ser distinta de cero';
  end if;

  if p_reason in ('SALE', 'REVERSAL') and p_quantity > 0
     or p_reason in ('PURCHASE', 'RETURN', 'INITIAL_STOCK') and p_quantity < 0 then
    raise exception 'El signo de la cantidad no coincide con el motivo';
  end if;

  select warehouse_id into selected_warehouse_id
  from public.inventory_locations
  where id = p_location_id and is_active;

  if selected_warehouse_id is null then
    raise exception 'La ubicación seleccionada no existe o está inactiva';
  end if;

  insert into public.inventory_transactions (
    product_id, warehouse_id, location_id, command_id, quantity, reason,
    notes, actor_name, device_name, device_identifier
  ) values (
    p_product_id, selected_warehouse_id, p_location_id, p_command_id,
    p_quantity, p_reason, nullif(trim(p_notes), ''), p_actor_name,
    p_device_name, p_device_identifier
  ) returning * into created_transaction;

  return created_transaction;
end;
$$;

create or replace function public.reverse_inventory_transaction(
  p_command_id uuid,
  p_original_transaction_id uuid,
  p_notes text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
)
returns public.inventory_transactions
language plpgsql
security invoker
set search_path = ''
as $$
declare
  existing_transaction public.inventory_transactions;
  original_transaction public.inventory_transactions;
  created_transaction public.inventory_transactions;
begin
  select * into existing_transaction
  from public.inventory_transactions
  where command_id = p_command_id;
  if found then return existing_transaction; end if;

  select * into original_transaction
  from public.inventory_transactions
  where id = p_original_transaction_id;

  if not found then raise exception 'El movimiento original no existe'; end if;
  if original_transaction.reason = 'REVERSAL' then
    raise exception 'Una reversión no puede revertirse directamente';
  end if;
  if nullif(trim(p_notes), '') is null then
    raise exception 'El motivo de la reversión es obligatorio';
  end if;

  insert into public.inventory_transactions (
    product_id, warehouse_id, location_id, command_id, quantity, reason,
    reversal_of_transaction_id, notes, actor_name, device_name,
    device_identifier
  ) values (
    original_transaction.product_id, original_transaction.warehouse_id,
    original_transaction.location_id, p_command_id,
    -original_transaction.quantity, 'REVERSAL', original_transaction.id,
    trim(p_notes), p_actor_name, p_device_name, p_device_identifier
  ) returning * into created_transaction;

  return created_transaction;
end;
$$;

create or replace function public.create_product_with_initial_stock(
  p_product jsonb,
  p_initial_stock integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
)
returns public.products
language plpgsql
security invoker
set search_path = ''
as $$
declare
  created_product public.products;
  default_warehouse_id uuid;
  default_location_id uuid;
begin
  if not exists (
    select 1 from public.packaging_presentations pp
    where pp.id = (p_product ->> 'packaging_presentation_id')::uuid
      and pp.is_active
  ) then
    raise exception 'La presentación seleccionada no existe o está inactiva';
  end if;

  select w.id, l.id into default_warehouse_id, default_location_id
  from public.warehouses w
  join public.inventory_locations l on l.warehouse_id = w.id
  where w.is_default and w.is_active and l.is_default and l.is_active
  limit 1;

  if default_location_id is null then
    raise exception 'No existe una ubicación predeterminada activa';
  end if;

  insert into public.products (
    id, sku, barcode, name, description, category_id, currency_code,
    unit_price, package_price, min_order_quantity, minimum_sale_quantity,
    packaging_presentation_id, cbm_per_moq, factory_cost, image_url,
    reorder_point, promo_price, promo_text, is_active, created_by,
    created_device_name, created_device_identifier
  ) values (
    (p_product ->> 'id')::uuid, p_product ->> 'sku',
    nullif(p_product ->> 'barcode', ''), p_product ->> 'name',
    coalesce(p_product ->> 'description', ''),
    (p_product ->> 'category_id')::uuid,
    coalesce(p_product ->> 'currency_code', 'USD'),
    (p_product ->> 'unit_price')::numeric,
    nullif(p_product ->> 'package_price', '')::numeric,
    (p_product ->> 'min_order_quantity')::integer,
    coalesce((p_product ->> 'minimum_sale_quantity')::integer, 1),
    (p_product ->> 'packaging_presentation_id')::uuid,
    (p_product ->> 'cbm_per_moq')::numeric,
    (p_product ->> 'factory_cost')::numeric,
    nullif(p_product ->> 'image_url', ''),
    (p_product ->> 'reorder_point')::integer,
    nullif(p_product ->> 'promo_price', '')::numeric,
    nullif(p_product ->> 'promo_text', ''),
    coalesce((p_product ->> 'is_active')::boolean, true),
    p_actor_name, p_device_name, p_device_identifier
  ) returning * into created_product;

  if p_initial_stock <> 0 then
    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      notes, actor_name, device_name, device_identifier
    ) values (
      created_product.id, default_warehouse_id, default_location_id,
      gen_random_uuid(), p_initial_stock, 'INITIAL_STOCK',
      'Stock inicial registrado al crear el producto', p_actor_name,
      p_device_name, p_device_identifier
    );
    select * into created_product from public.products
    where id = created_product.id;
  end if;

  return created_product;
end;
$$;

create trigger warehouses_set_updated_at before update on public.warehouses
for each row execute function public.set_updated_at();
create trigger inventory_locations_set_updated_at before update on public.inventory_locations
for each row execute function public.set_updated_at();

alter table public.warehouses enable row level security;
alter table public.inventory_locations enable row level security;
alter table public.inventory_balances enable row level security;

create policy warehouses_local_access on public.warehouses for all
  to anon, authenticated using (true) with check (true);
create policy inventory_locations_local_access on public.inventory_locations for all
  to anon, authenticated using (true) with check (true);
create policy inventory_balances_local_read on public.inventory_balances for select
  to anon, authenticated using (true);

grant select, insert, update on public.warehouses to anon, authenticated;
grant select, insert, update on public.inventory_locations to anon, authenticated;
grant select on public.inventory_balances to anon, authenticated;
grant execute on function public.record_inventory_transaction(
  uuid, uuid, uuid, integer, public.inventory_transaction_reason,
  text, text, text, text
) to anon, authenticated;
grant execute on function public.reverse_inventory_transaction(
  uuid, uuid, text, text, text, text
) to anon, authenticated;
