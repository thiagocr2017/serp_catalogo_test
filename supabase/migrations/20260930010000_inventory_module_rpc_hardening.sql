-- Bloque 1D: Endurecer API de Inventario
-- Reemplaza escritura directa sobre warehouses e inventory_locations por RPCs.

-- 1. RPC create_warehouse
create or replace function public.create_warehouse(
  p_code text,
  p_name text,
  p_is_default boolean,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.warehouses
language plpgsql security invoker set search_path = '' as $$
declare
  v_id uuid;
begin
  if btrim(p_code) = '' or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if exists (
    select 1 from public.warehouses
    where code = btrim(p_code) and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_WAREHOUSE_CODE';
  end if;
  if p_is_default then
    update public.warehouses set is_default = false where is_active;
  end if;
  insert into public.warehouses (
    code, name, is_default,
    created_by, created_device_name, created_device_identifier
  ) values (
    btrim(p_code), btrim(p_name), p_is_default,
    p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_id;
  return (select * from public.warehouses where id = v_id);
end;
$$;

revoke all on function public.create_warehouse(text, text, boolean, text, text, text)
  from public;
grant execute on function public.create_warehouse(text, text, boolean, text, text, text)
  to anon, authenticated;

-- 2. RPC update_warehouse
create or replace function public.update_warehouse(
  p_warehouse_id uuid,
  p_code text,
  p_name text,
  p_is_default boolean,
  p_is_active boolean,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.warehouses
language plpgsql security invoker set search_path = '' as $$
declare
  v public.warehouses%rowtype;
begin
  if btrim(p_code) = '' or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if exists (
    select 1 from public.warehouses
    where code = btrim(p_code) and is_active and id <> p_warehouse_id
  ) then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_WAREHOUSE_CODE';
  end if;
  if p_is_default then
    update public.warehouses set is_default = false
    where is_active and id <> p_warehouse_id;
  end if;
  update public.warehouses
     set code = btrim(p_code),
         name = btrim(p_name),
         is_default = p_is_default,
         is_active = p_is_active,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_warehouse_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$$;

revoke all on function public.update_warehouse(uuid, text, text, boolean, boolean, text, text, text)
  from public;
grant execute on function public.update_warehouse(uuid, text, text, boolean, boolean, text, text, text)
  to anon, authenticated;

-- 3. RPC create_inventory_location
create or replace function public.create_inventory_location(
  p_warehouse_id uuid,
  p_code text,
  p_name text,
  p_is_default boolean,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.inventory_locations
language plpgsql security invoker set search_path = '' as $$
declare
  v_id uuid;
begin
  if btrim(p_code) = '' or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if not exists (
    select 1 from public.warehouses
    where id = p_warehouse_id and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'WAREHOUSE_NOT_FOUND';
  end if;
  if exists (
    select 1 from public.inventory_locations
    where warehouse_id = p_warehouse_id and code = btrim(p_code) and is_active
  ) then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_LOCATION_CODE';
  end if;
  if p_is_default then
    update public.inventory_locations set is_default = false
    where warehouse_id = p_warehouse_id and is_active;
  end if;
  insert into public.inventory_locations (
    warehouse_id, code, name, is_default,
    created_by, created_device_name, created_device_identifier
  ) values (
    p_warehouse_id, btrim(p_code), btrim(p_name), p_is_default,
    p_actor_name, p_device_name, p_device_identifier
  ) returning id into v_id;
  return (select * from public.inventory_locations where id = v_id);
end;
$$;

revoke all on function public.create_inventory_location(uuid, text, text, boolean, text, text, text)
  from public;
grant execute on function public.create_inventory_location(uuid, text, text, boolean, text, text, text)
  to anon, authenticated;

-- 4. RPC update_inventory_location
create or replace function public.update_inventory_location(
  p_location_id uuid,
  p_code text,
  p_name text,
  p_is_default boolean,
  p_is_active boolean,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.inventory_locations
language plpgsql security invoker set search_path = '' as $$
declare
  v public.inventory_locations%rowtype;
begin
  if btrim(p_code) = '' or btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if exists (
    select 1 from public.inventory_locations
    where warehouse_id = (select warehouse_id from public.inventory_locations where id = p_location_id)
      and code = btrim(p_code) and is_active and id <> p_location_id
  ) then
    raise exception using errcode = 'P0001', message = 'DUPLICATE_LOCATION_CODE';
  end if;
  if p_is_default then
    update public.inventory_locations set is_default = false
    where warehouse_id = (select warehouse_id from public.inventory_locations where id = p_location_id)
      and is_active and id <> p_location_id;
  end if;
  update public.inventory_locations
     set code = btrim(p_code),
         name = btrim(p_name),
         is_default = p_is_default,
         is_active = p_is_active,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_location_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$$;

revoke all on function public.update_inventory_location(uuid, text, text, boolean, boolean, text, text, text)
  from public;
grant execute on function public.update_inventory_location(uuid, text, text, boolean, boolean, text, text, text)
  to anon, authenticated;

-- 5. Revocar escritura directa sobre tablas de inventario
revoke insert, update, delete, truncate, references, trigger
  on table public.warehouses
  from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on table public.inventory_locations
  from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on table public.inventory_documents
  from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on table public.inventory_document_lines
  from anon, authenticated;

-- Mantener SELECT para lecturas
grant select on table public.warehouses to anon, authenticated;
grant select on table public.inventory_locations to anon, authenticated;
grant select on table public.inventory_documents to anon, authenticated;
grant select on table public.inventory_document_lines to anon, authenticated;
