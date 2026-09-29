alter type public.inventory_transaction_reason add value if not exists 'TRANSFER_OUT';
alter type public.inventory_transaction_reason add value if not exists 'TRANSFER_IN';

create type public.inventory_document_type as enum (
  'OPENING', 'ADJUSTMENT', 'TRANSFER', 'PURCHASE_RECEIPT',
  'SALE_DISPATCH', 'CUSTOMER_RETURN', 'SUPPLIER_RETURN', 'CONSIGNMENT'
);
create type public.inventory_document_status as enum (
  'DRAFT', 'CONFIRMED', 'CANCELLED'
);

create sequence public.inventory_document_number_seq;

create table public.inventory_documents (
  id uuid primary key default gen_random_uuid(),
  command_id uuid not null unique,
  document_number text not null unique,
  document_type public.inventory_document_type not null,
  status public.inventory_document_status not null default 'DRAFT',
  origin_warehouse_id uuid references public.warehouses(id),
  origin_location_id uuid references public.inventory_locations(id),
  destination_warehouse_id uuid references public.warehouses(id),
  destination_location_id uuid references public.inventory_locations(id),
  external_reference text,
  notes text,
  confirmed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  created_by text,
  updated_by text,
  created_device_name text,
  created_device_identifier text,
  updated_device_name text,
  updated_device_identifier text,
  foreign key (origin_location_id, origin_warehouse_id)
    references public.inventory_locations(id, warehouse_id),
  foreign key (destination_location_id, destination_warehouse_id)
    references public.inventory_locations(id, warehouse_id)
);

create table public.inventory_document_lines (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.inventory_documents(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null check (quantity <> 0),
  notes text,
  created_at timestamptz not null default now()
);

create index inventory_documents_created_idx
  on public.inventory_documents(created_at desc);
create index inventory_document_lines_document_idx
  on public.inventory_document_lines(document_id);

alter table public.inventory_transactions
  add column document_id uuid references public.inventory_documents(id),
  add column document_line_id uuid references public.inventory_document_lines(id);

create index inventory_transactions_document_idx
  on public.inventory_transactions(document_id, created_at desc);

create or replace function public.inventory_document_prefix(
  p_type public.inventory_document_type
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_type
    when 'OPENING' then 'APE'
    when 'ADJUSTMENT' then 'AJU'
    when 'TRANSFER' then 'TRA'
    when 'PURCHASE_RECEIPT' then 'REC'
    when 'SALE_DISPATCH' then 'DES'
    when 'CUSTOMER_RETURN' then 'DCL'
    when 'SUPPLIER_RETURN' then 'DPR'
    when 'CONSIGNMENT' then 'CON'
  end;
$$;

create or replace function public.default_inventory_location(
  p_warehouse_id uuid default null
)
returns public.inventory_locations
language plpgsql
stable
set search_path = ''
as $$
declare
  selected_location public.inventory_locations;
begin
  select l.* into selected_location
  from public.inventory_locations l
  join public.warehouses w on w.id = l.warehouse_id
  where l.is_active and w.is_active
    and (p_warehouse_id is null or w.id = p_warehouse_id)
  order by
    case when p_warehouse_id is null then w.is_default else true end desc,
    l.is_default desc,
    l.name
  limit 1;
  return selected_location;
end;
$$;

create or replace function public.create_and_confirm_inventory_document(
  p_command_id uuid,
  p_document_type public.inventory_document_type,
  p_lines jsonb,
  p_origin_warehouse_id uuid,
  p_origin_location_id uuid,
  p_destination_warehouse_id uuid,
  p_destination_location_id uuid,
  p_external_reference text,
  p_notes text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
)
returns public.inventory_documents
language plpgsql
security invoker
set search_path = ''
as $$
declare
  existing_document public.inventory_documents;
  created_document public.inventory_documents;
  created_line public.inventory_document_lines;
  origin_location public.inventory_locations;
  destination_location public.inventory_locations;
  line jsonb;
  line_quantity integer;
  movement_quantity integer;
begin
  select d.* into existing_document
  from public.inventory_documents d
  where d.command_id = p_command_id;
  if found then return existing_document; end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) = 0 then
    raise exception 'El documento necesita al menos un producto';
  end if;

  if p_origin_location_id is not null then
    select * into origin_location from public.inventory_locations
    where id = p_origin_location_id and is_active;
  else
    origin_location := public.default_inventory_location(p_origin_warehouse_id);
  end if;
  if p_destination_location_id is not null then
    select * into destination_location from public.inventory_locations
    where id = p_destination_location_id and is_active;
  else
    destination_location := public.default_inventory_location(p_destination_warehouse_id);
  end if;

  if p_document_type in ('TRANSFER', 'SALE_DISPATCH', 'SUPPLIER_RETURN', 'CONSIGNMENT')
     and origin_location.id is null then
    raise exception 'No existe una ubicación de origen activa';
  end if;
  if p_document_type in ('OPENING', 'ADJUSTMENT', 'TRANSFER', 'PURCHASE_RECEIPT', 'CUSTOMER_RETURN')
     and destination_location.id is null then
    raise exception 'No existe una ubicación de destino activa';
  end if;
  if p_document_type = 'TRANSFER' and origin_location.id = destination_location.id then
    raise exception 'El origen y el destino del traslado deben ser diferentes';
  end if;

  insert into public.inventory_documents (
    command_id, document_number, document_type, status,
    origin_warehouse_id, origin_location_id,
    destination_warehouse_id, destination_location_id,
    external_reference, notes, confirmed_at,
    created_by, created_device_name, created_device_identifier
  ) values (
    p_command_id,
    public.inventory_document_prefix(p_document_type) || '-' ||
      lpad(nextval('public.inventory_document_number_seq')::text, 8, '0'),
    p_document_type, 'CONFIRMED',
    origin_location.warehouse_id, origin_location.id,
    destination_location.warehouse_id, destination_location.id,
    nullif(trim(p_external_reference), ''), nullif(trim(p_notes), ''), now(),
    p_actor_name, p_device_name, p_device_identifier
  ) returning * into created_document;

  for line in select value from jsonb_array_elements(p_lines)
  loop
    line_quantity := (line ->> 'quantity')::integer;
    if line_quantity = 0 then raise exception 'La cantidad no puede ser cero'; end if;

    insert into public.inventory_document_lines (
      document_id, product_id, quantity, notes
    ) values (
      created_document.id, (line ->> 'product_id')::uuid,
      line_quantity, nullif(trim(line ->> 'notes'), '')
    ) returning * into created_line;

    if p_document_type = 'TRANSFER' then
      insert into public.inventory_transactions (
        product_id, warehouse_id, location_id, command_id, quantity, reason,
        document_id, document_line_id, notes, actor_name,
        device_name, device_identifier
      ) values (
        created_line.product_id, origin_location.warehouse_id,
        origin_location.id, gen_random_uuid(), -abs(line_quantity),
        'TRANSFER_OUT', created_document.id, created_line.id,
        created_document.document_number, p_actor_name,
        p_device_name, p_device_identifier
      );
      insert into public.inventory_transactions (
        product_id, warehouse_id, location_id, command_id, quantity, reason,
        document_id, document_line_id, notes, actor_name,
        device_name, device_identifier
      ) values (
        created_line.product_id, destination_location.warehouse_id,
        destination_location.id, gen_random_uuid(), abs(line_quantity),
        'TRANSFER_IN', created_document.id, created_line.id,
        created_document.document_number, p_actor_name,
        p_device_name, p_device_identifier
      );
    else
      movement_quantity := case p_document_type
        when 'SALE_DISPATCH' then -abs(line_quantity)
        when 'SUPPLIER_RETURN' then -abs(line_quantity)
        when 'CONSIGNMENT' then -abs(line_quantity)
        when 'ADJUSTMENT' then line_quantity
        else abs(line_quantity)
      end;
      insert into public.inventory_transactions (
        product_id, warehouse_id, location_id, command_id, quantity, reason,
        document_id, document_line_id, notes, actor_name,
        device_name, device_identifier
      ) values (
        created_line.product_id,
        case when movement_quantity < 0 then origin_location.warehouse_id
             else destination_location.warehouse_id end,
        case when movement_quantity < 0 then origin_location.id
             else destination_location.id end,
        case when jsonb_array_length(p_lines) = 1 then p_command_id
             else gen_random_uuid() end,
        movement_quantity,
        case p_document_type
          when 'OPENING' then 'INITIAL_STOCK'::public.inventory_transaction_reason
          when 'ADJUSTMENT' then 'ADJUSTMENT'::public.inventory_transaction_reason
          when 'PURCHASE_RECEIPT' then 'PURCHASE'::public.inventory_transaction_reason
          when 'CUSTOMER_RETURN' then 'RETURN'::public.inventory_transaction_reason
          else 'SALE'::public.inventory_transaction_reason
        end,
        created_document.id, created_line.id, created_document.document_number,
        p_actor_name, p_device_name, p_device_identifier
      );
    end if;
  end loop;

  return created_document;
end;
$$;

create trigger inventory_documents_set_updated_at
before update on public.inventory_documents
for each row execute function public.set_updated_at();
create trigger inventory_documents_audit
after insert or update on public.inventory_documents
for each row execute function public.write_audit_log();

alter table public.inventory_documents enable row level security;
alter table public.inventory_document_lines enable row level security;
create policy inventory_documents_local_access on public.inventory_documents
  for all to anon, authenticated using (true) with check (true);
create policy inventory_document_lines_local_access on public.inventory_document_lines
  for all to anon, authenticated using (true) with check (true);

grant select, insert, update on public.inventory_documents to anon, authenticated;
grant select, insert, update on public.inventory_document_lines to anon, authenticated;
grant usage, select on sequence public.inventory_document_number_seq to anon, authenticated;
grant execute on function public.create_and_confirm_inventory_document(
  uuid, public.inventory_document_type, jsonb, uuid, uuid, uuid, uuid,
  text, text, text, text, text
) to anon, authenticated;
