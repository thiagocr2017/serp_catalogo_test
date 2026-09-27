create extension if not exists pgcrypto;

create type public.packaging_type as enum ('UNIT', 'BOX', 'SET');
create type public.inventory_transaction_reason as enum (
  'INITIAL_STOCK', 'PURCHASE', 'SALE', 'ADJUSTMENT', 'RETURN', 'REVERSAL'
);
create type public.audit_operation as enum ('INSERT', 'UPDATE', 'SOFT_DELETE');

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (length(trim(name)) > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  deleted_at timestamptz,
  created_by text,
  updated_by text,
  deleted_by text,
  created_device_name text,
  created_device_identifier text,
  updated_device_name text,
  updated_device_identifier text
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique check (length(trim(sku)) > 0),
  barcode text unique,
  name text not null check (length(trim(name)) > 0),
  description text not null default '',
  category_id uuid not null references public.categories(id),
  currency_code char(3) not null default 'USD',
  unit_price numeric(18, 2) not null check (unit_price >= 0),
  package_price numeric(18, 2) check (package_price is null or package_price >= 0),
  min_order_quantity integer not null default 1 check (min_order_quantity > 0),
  packaging_type public.packaging_type not null default 'UNIT',
  cbm_per_moq numeric(18, 6) not null default 0 check (cbm_per_moq >= 0),
  factory_cost numeric(18, 2) not null default 0 check (factory_cost >= 0),
  image_url text,
  current_stock integer not null default 0,
  reorder_point integer not null default 0 check (reorder_point >= 0),
  promo_price numeric(18, 2) check (promo_price is null or promo_price >= 0),
  promo_text text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  deleted_at timestamptz,
  created_by text,
  updated_by text,
  deleted_by text,
  created_device_name text,
  created_device_identifier text,
  updated_device_name text,
  updated_device_identifier text
);

create index products_category_id_idx on public.products(category_id);
create index products_active_category_idx on public.products(is_active, category_id);

create table public.inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  quantity integer not null check (quantity <> 0),
  reason public.inventory_transaction_reason not null,
  reversal_of_transaction_id uuid references public.inventory_transactions(id),
  notes text,
  actor_user_id uuid,
  actor_name text,
  device_name text not null,
  device_identifier text not null,
  created_at timestamptz not null default now(),
  check (reason = 'REVERSAL' or reversal_of_transaction_id is null),
  check (reason <> 'REVERSAL' or reversal_of_transaction_id is not null)
);

create index inventory_transactions_product_created_idx
  on public.inventory_transactions(product_id, created_at desc);

create unique index one_reversal_per_transaction_idx
  on public.inventory_transactions(reversal_of_transaction_id)
  where reversal_of_transaction_id is not null;

create table public.bulk_promotions (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  discount_percentage numeric(5, 2) not null
    check (discount_percentage > 0 and discount_percentage <= 100),
  conditions_text text not null default '',
  badge_image_url text,
  start_date timestamptz,
  end_date timestamptz not null,
  applies_to_all_products boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  deleted_at timestamptz,
  created_by text,
  updated_by text,
  deleted_by text,
  created_device_name text,
  created_device_identifier text,
  updated_device_name text,
  updated_device_identifier text,
  check (start_date is null or end_date > start_date)
);

create table public.bulk_promotion_products (
  promotion_id uuid not null references public.bulk_promotions(id) on delete cascade,
  product_id uuid not null references public.products(id),
  primary key (promotion_id, product_id)
);

create table public.bulk_promotion_categories (
  promotion_id uuid not null references public.bulk_promotions(id) on delete cascade,
  category_id uuid not null references public.categories(id),
  primary key (promotion_id, category_id)
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  table_name text not null,
  record_id uuid not null,
  operation public.audit_operation not null,
  field_name text,
  old_value text,
  new_value text,
  actor_user_id uuid,
  actor_name text,
  device_name text,
  device_identifier text,
  created_at timestamptz not null default now()
);

create index audit_logs_record_idx
  on public.audit_logs(table_name, record_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger categories_set_updated_at before update on public.categories
for each row execute function public.set_updated_at();
create trigger products_set_updated_at before update on public.products
for each row execute function public.set_updated_at();
create trigger bulk_promotions_set_updated_at before update on public.bulk_promotions
for each row execute function public.set_updated_at();

create or replace function public.apply_inventory_transaction()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  update public.products
     set current_stock = current_stock + new.quantity,
         updated_by = coalesce(new.actor_name, 'device:' || new.device_identifier),
         updated_device_name = new.device_name,
         updated_device_identifier = new.device_identifier
   where id = new.product_id;

  if not found then
    raise exception 'Product % does not exist', new.product_id;
  end if;

  return new;
end;
$$;

create trigger inventory_transaction_apply_stock
after insert on public.inventory_transactions
for each row execute function public.apply_inventory_transaction();

create or replace function public.prevent_inventory_transaction_changes()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Inventory transactions are immutable; insert a reversal instead';
end;
$$;

create trigger inventory_transactions_no_update_or_delete
before update or delete on public.inventory_transactions
for each row execute function public.prevent_inventory_transaction_changes();

create or replace function public.write_audit_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_data jsonb := case when tg_op = 'INSERT' then '{}'::jsonb else to_jsonb(old) end;
  new_data jsonb := case when tg_op = 'DELETE' then '{}'::jsonb else to_jsonb(new) end;
  key text;
  audit_operation public.audit_operation;
begin
  audit_operation := case
    when tg_op = 'INSERT' then 'INSERT'::public.audit_operation
    when coalesce((new_data ->> 'is_active')::boolean, true) = false
      and coalesce((old_data ->> 'is_active')::boolean, true) = true
      then 'SOFT_DELETE'::public.audit_operation
    else 'UPDATE'::public.audit_operation
  end;

  for key in select jsonb_object_keys(old_data || new_data)
  loop
    if old_data -> key is distinct from new_data -> key then
      insert into public.audit_logs (
        table_name, record_id, operation, field_name, old_value, new_value,
        actor_user_id, actor_name, device_name, device_identifier
      ) values (
        tg_table_name,
        coalesce((new_data ->> 'id')::uuid, (old_data ->> 'id')::uuid),
        audit_operation,
        key,
        old_data ->> key,
        new_data ->> key,
        nullif(new_data ->> 'actor_user_id', '')::uuid,
        coalesce(new_data ->> 'updated_by', new_data ->> 'created_by'),
        coalesce(new_data ->> 'updated_device_name', new_data ->> 'created_device_name'),
        coalesce(new_data ->> 'updated_device_identifier', new_data ->> 'created_device_identifier')
      );
    end if;
  end loop;

  return coalesce(new, old);
end;
$$;

create trigger categories_audit after insert or update on public.categories
for each row execute function public.write_audit_log();
create trigger products_audit after insert or update on public.products
for each row execute function public.write_audit_log();
create trigger bulk_promotions_audit after insert or update on public.bulk_promotions
for each row execute function public.write_audit_log();

alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.bulk_promotions enable row level security;
alter table public.bulk_promotion_products enable row level security;
alter table public.bulk_promotion_categories enable row level security;
alter table public.audit_logs enable row level security;

-- Temporary policies for the desktop application before authentication exists.
-- Replace these policies with role-based policies before production deployment.
create policy categories_local_access on public.categories for all to anon, authenticated
using (true) with check (true);
create policy products_local_access on public.products for all to anon, authenticated
using (true) with check (true);
create policy inventory_local_read on public.inventory_transactions for select to anon, authenticated using (true);
create policy inventory_local_insert on public.inventory_transactions for insert to anon, authenticated with check (true);
create policy promotions_local_access on public.bulk_promotions for all to anon, authenticated
using (true) with check (true);
create policy promotion_products_local_access on public.bulk_promotion_products for all to anon, authenticated
using (true) with check (true);
create policy promotion_categories_local_access on public.bulk_promotion_categories for all to anon, authenticated
using (true) with check (true);
create policy audit_local_read on public.audit_logs for select to anon, authenticated using (true);

grant usage on schema public to anon, authenticated;
grant select, insert, update on public.categories to anon, authenticated;
grant select, insert, update on public.products to anon, authenticated;
grant select, insert on public.inventory_transactions to anon, authenticated;
grant select, insert, update on public.bulk_promotions to anon, authenticated;
grant select, insert, update, delete on public.bulk_promotion_products to anon, authenticated;
grant select, insert, update, delete on public.bulk_promotion_categories to anon, authenticated;
grant select on public.audit_logs to anon, authenticated;
