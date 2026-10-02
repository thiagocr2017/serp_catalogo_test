-- Datos comerciales del cliente y compradores por producto
--
-- 1. customers suma province y gira (agrupación comercial libre, p. ej.
--    la ruta de visita). Se extienden create/update_customer.
-- 2. customer_contacts guarda las personas de contacto de cada empresa
--    con sus RPC de escritura.
-- 3. product_buyers lista quiénes compran un producto a partir de líneas
--    de facturas confirmadas y pedidos no anulados, con contactos
--    embebidos para la búsqueda del display de producto.

alter table public.customers
  add column if not exists province text,
  add column if not exists gira text;

create table if not exists public.customer_contacts (
  id uuid primary key default extensions.gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  name text not null,
  phone text,
  role text,
  created_by text,
  created_device_name text,
  created_device_identifier text,
  created_at timestamptz not null default now()
);

alter table public.customer_contacts enable row level security;
revoke all on public.customer_contacts from public, anon, authenticated;
grant select on public.customer_contacts to anon, authenticated;
drop policy if exists customer_contacts_local_access on public.customer_contacts;
create policy customer_contacts_local_access on public.customer_contacts
  for all to anon, authenticated using (true);

-- ============================================================
-- create_customer / update_customer con province y gira
-- ============================================================

drop function if exists
  public.create_customer(text, text, text, text, text, numeric, text, text, text);
drop function if exists
  public.update_customer(uuid, text, text, text, text, text, numeric, text, text, text);

create or replace function public.create_customer(
  p_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_province text,
  p_gira text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_row public.customers%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  insert into public.customers (
    name, phone, email, address, tax_id, credit_limit,
    province, gira,
    created_by, created_device_name, created_device_identifier
  )
  values (
    btrim(p_name), p_phone, p_email, p_address, p_tax_id,
    coalesce(p_credit_limit, 0),
    nullif(btrim(p_province), ''), nullif(btrim(p_gira), ''),
    p_actor_name, p_device_name, p_device_identifier
  )
  returning id into v_id;
  select * into v_row from public.customers where id = v_id;
  return v_row;
end;
$$;

revoke all on function public.create_customer(text, text, text, text, text, numeric, text, text, text, text, text) from public;
grant execute on function public.create_customer(text, text, text, text, text, numeric, text, text, text, text, text) to anon, authenticated;

create or replace function public.update_customer(
  p_customer_id uuid,
  p_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
  p_province text,
  p_gira text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customers
language plpgsql security definer set search_path = '' as $$
declare
  v public.customers%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  update public.customers
     set name = btrim(p_name),
         phone = p_phone,
         email = p_email,
         address = p_address,
         tax_id = p_tax_id,
         credit_limit = p_credit_limit,
         province = nullif(btrim(p_province), ''),
         gira = nullif(btrim(p_gira), ''),
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_customer_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$$;

revoke all on function public.update_customer(uuid, text, text, text, text, text, numeric, text, text, text, text, text) from public;
grant execute on function public.update_customer(uuid, text, text, text, text, text, numeric, text, text, text, text, text) to anon, authenticated;

-- ============================================================
-- Contactos del cliente
-- ============================================================

create or replace function public.create_customer_contact(
  p_customer_id uuid,
  p_name text,
  p_phone text,
  p_role text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customer_contacts
language plpgsql security definer set search_path = '' as $$
declare
  v public.customer_contacts%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if not exists (select 1 from public.customers where id = p_customer_id) then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  insert into public.customer_contacts (
    customer_id, name, phone, role,
    created_by, created_device_name, created_device_identifier
  )
  values (
    p_customer_id, btrim(p_name),
    nullif(btrim(p_phone), ''), nullif(btrim(p_role), ''),
    p_actor_name, p_device_name, p_device_identifier
  )
  returning * into v;
  return v;
end;
$$;

revoke all on function public.create_customer_contact(uuid, text, text, text, text, text, text) from public;
grant execute on function public.create_customer_contact(uuid, text, text, text, text, text, text) to anon, authenticated;

create or replace function public.update_customer_contact(
  p_contact_id uuid,
  p_name text,
  p_phone text,
  p_role text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customer_contacts
language plpgsql security definer set search_path = '' as $$
declare
  v public.customer_contacts%rowtype;
begin
  if btrim(p_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  update public.customer_contacts
     set name = btrim(p_name),
         phone = nullif(btrim(p_phone), ''),
         role = nullif(btrim(p_role), '')
   where id = p_contact_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$$;

revoke all on function public.update_customer_contact(uuid, text, text, text, text, text, text) from public;
grant execute on function public.update_customer_contact(uuid, text, text, text, text, text, text) to anon, authenticated;

create or replace function public.delete_customer_contact(
  p_contact_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.customer_contacts where id = p_contact_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
end;
$$;

revoke all on function public.delete_customer_contact(uuid, text, text, text) from public;
grant execute on function public.delete_customer_contact(uuid, text, text, text) to anon, authenticated;

-- ============================================================
-- Compradores de un producto
--
-- Compran = líneas en facturas confirmadas/pagadas y en pedidos no
-- anulados. Las facturas creadas solo con nombre (sin customer_id) se
-- vinculan por coincidencia exacta de nombre; si el nombre no existe
-- como cliente aparece como fila invitada (customer_id nulo).
-- ============================================================

create or replace function public.product_buyers(p_product_id uuid)
returns table (
  customer_id uuid,
  customer_name text,
  phone text,
  email text,
  province text,
  gira text,
  is_active boolean,
  last_purchase_at timestamptz,
  total_quantity integer,
  documents_count integer,
  contacts jsonb
)
language plpgsql security definer set search_path = '' as $$
begin
  return query
  with lines as (
    select il.invoice_id as doc_id, il.quantity, i.created_at,
           i.customer_id, i.customer_name
      from public.sales_invoice_lines il
      join public.sales_invoices i on i.id = il.invoice_id
     where il.product_id = p_product_id
       and i.status in ('CONFIRMED', 'PAID')
    union all
    select ol.order_id, ol.quantity, o.created_at,
           o.customer_id, o.customer_name
      from public.sales_order_lines ol
      join public.sales_orders o on o.id = ol.order_id
     where ol.product_id = p_product_id
       and o.status <> 'CANCELLED'
  ),
  grouped as (
    select c.id as cid,
           coalesce(c.name, l.customer_name) as cname,
           max(l.created_at) as last_at,
           sum(l.quantity)::integer as qty,
           count(distinct l.doc_id)::integer as docs
      from lines l
      left join public.customers c
        on c.id = l.customer_id
        or (l.customer_id is null and c.name = l.customer_name)
     group by 1, 2
  )
  select g.cid,
         g.cname,
         c.phone,
         c.email,
         c.province,
         c.gira,
         c.is_active,
         g.last_at,
         g.qty,
         g.docs,
         coalesce((
           select jsonb_agg(
             jsonb_build_object(
               'id', cc.id, 'name', cc.name,
               'phone', cc.phone, 'role', cc.role
             )
             order by cc.name
           )
           from public.customer_contacts cc
          where cc.customer_id = g.cid
         ), '[]'::jsonb)
    from grouped g
    left join public.customers c on c.id = g.cid
   order by g.last_at desc;
end;
$$;

revoke all on function public.product_buyers(uuid) from public;
grant execute on function public.product_buyers(uuid) to anon, authenticated;
