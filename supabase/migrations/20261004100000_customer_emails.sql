-- Correos documentales del cliente: principal y copias.
-- Decisiones 13, 21 y 22 de .specs/modules/sales/customer-management/0.open-questions.md.

create table if not exists public.customer_emails (
  id uuid primary key default extensions.gen_random_uuid(),
  customer_id uuid not null references public.customers(id) on delete cascade,
  email text not null,
  purpose text not null default 'COPY' check (purpose in ('PRIMARY', 'COPY')),
  label text,
  is_active boolean not null default true,
  created_by text,
  created_device_name text,
  created_device_identifier text,
  created_at timestamptz not null default now(),
  updated_by text,
  updated_device_name text,
  updated_device_identifier text,
  updated_at timestamptz
);

alter table public.customer_emails enable row level security;
revoke all on public.customer_emails from public, anon, authenticated;
grant select on public.customer_emails to anon, authenticated;

drop policy if exists customer_emails_local_access on public.customer_emails;
create policy customer_emails_local_access on public.customer_emails
  for all to anon, authenticated using (true);

create or replace function public.create_customer_email(
  p_customer_id uuid,
  p_email text,
  p_purpose text,
  p_label text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customer_emails
language plpgsql security definer set search_path = '' as $$
declare
  v public.customer_emails%rowtype;
  v_purpose text;
begin
  if btrim(p_email) = '' or position('@' in btrim(p_email)) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_EMAIL';
  end if;
  v_purpose := coalesce(p_purpose, 'COPY');
  if v_purpose not in ('PRIMARY', 'COPY') then
    raise exception using errcode = 'P0001', message = 'INVALID_PURPOSE';
  end if;

  if v_purpose = 'PRIMARY' then
    update public.customer_emails
       set purpose = 'COPY',
           updated_by = p_actor_name,
           updated_device_name = p_device_name,
           updated_device_identifier = p_device_identifier,
           updated_at = now()
     where customer_id = p_customer_id
       and purpose = 'PRIMARY';
  end if;

  insert into public.customer_emails (
    customer_id, email, purpose, label,
    created_by, created_device_name, created_device_identifier
  )
  values (
    p_customer_id, btrim(p_email), v_purpose, nullif(btrim(p_label), ''),
    p_actor_name, p_device_name, p_device_identifier
  )
  returning * into v;
  return v;
end;
$$;

revoke all on function public.create_customer_email(uuid, text, text, text, text, text, text) from public;
grant execute on function public.create_customer_email(uuid, text, text, text, text, text, text) to anon, authenticated;

create or replace function public.update_customer_email(
  p_email_id uuid,
  p_email text,
  p_purpose text,
  p_label text,
  p_is_active boolean,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.customer_emails
language plpgsql security definer set search_path = '' as $$
declare
  v public.customer_emails%rowtype;
  v_customer_id uuid;
  v_purpose text;
begin
  select customer_id into v_customer_id
    from public.customer_emails
   where id = p_email_id;
  if v_customer_id is null then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;

  if btrim(p_email) = '' or position('@' in btrim(p_email)) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_EMAIL';
  end if;
  v_purpose := coalesce(p_purpose, 'COPY');
  if v_purpose not in ('PRIMARY', 'COPY') then
    raise exception using errcode = 'P0001', message = 'INVALID_PURPOSE';
  end if;

  if v_purpose = 'PRIMARY' then
    update public.customer_emails
       set purpose = 'COPY',
           updated_by = p_actor_name,
           updated_device_name = p_device_name,
           updated_device_identifier = p_device_identifier,
           updated_at = now()
     where customer_id = v_customer_id
       and purpose = 'PRIMARY'
       and id != p_email_id;
  end if;

  update public.customer_emails
     set email = btrim(p_email),
         purpose = v_purpose,
         label = nullif(btrim(p_label), ''),
         is_active = coalesce(p_is_active, true),
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_email_id
  returning * into v;
  return v;
end;
$$;

revoke all on function public.update_customer_email(uuid, text, text, text, boolean, text, text, text) from public;
grant execute on function public.update_customer_email(uuid, text, text, text, boolean, text, text, text) to anon, authenticated;

create or replace function public.delete_customer_email(
  p_email_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.customer_emails where id = p_email_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
end;
$$;

revoke all on function public.delete_customer_email(uuid, text, text, text) from public;
grant execute on function public.delete_customer_email(uuid, text, text, text) to anon, authenticated;
