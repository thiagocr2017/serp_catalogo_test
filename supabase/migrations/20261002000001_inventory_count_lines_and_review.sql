-- Líneas de conteo y estado REVIEW para confirmación
--
-- El RPC confirm_count_and_adjust exige líneas con difference <> 0 y reviewed=true.
-- Se añade tabla inventory_count_lines si no existe y se extiende el RPC
-- create_inventory_count para crear líneas en borrador.

-- 1. Tabla de líneas de conteo (si no existe)
create table if not exists public.inventory_count_lines (
  id uuid primary key default extensions.gen_random_uuid(),
  count_id uuid not null references public.inventory_counts(id) on delete cascade,
  product_id uuid not null references public.products(id),
  expected_quantity integer not null,
  counted_quantity integer,
  difference integer generated always as (coalesce(counted_quantity, 0) - expected_quantity) stored,
  reviewed boolean not null default false,
  notes text,
  created_by text,
  created_device_name text,
  created_device_identifier text,
  updated_by text,
  updated_device_name text,
  updated_device_identifier text,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  unique (count_id, product_id)
);

-- Asegurar columnas en tablas preexistentes
alter table public.inventory_count_lines
  add column if not exists created_by text,
  add column if not exists created_device_name text,
  add column if not exists created_device_identifier text,
  add column if not exists updated_by text,
  add column if not exists updated_device_name text,
  add column if not exists updated_device_identifier text,
  add column if not exists updated_at timestamptz,
  add column if not exists notes text,
  drop column if exists location_id,
  drop column if exists justification;

alter table public.inventory_count_lines enable row level security;
revoke all on public.inventory_count_lines from public, anon, authenticated;
grant select on public.inventory_count_lines to anon, authenticated;
drop policy if exists inventory_count_lines_local_access on public.inventory_count_lines;
create policy inventory_count_lines_local_access on public.inventory_count_lines
  for all to anon, authenticated using (true);

-- 2. Extender create_inventory_count para crear líneas en borrador
drop function if exists public.create_inventory_count(
  uuid, text, text, text
);

create or replace function public.create_inventory_count(
  p_warehouse_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text,
  p_lines jsonb default '[]'::jsonb
) returns public.inventory_counts
language plpgsql security definer set search_path = '' as $$
declare
  v_count public.inventory_counts%rowtype;
  v_line jsonb;
  v_product_id uuid;
  v_expected_qty integer;
begin
  insert into public.inventory_counts (
    warehouse_id, status, created_by, created_device_name, created_device_identifier
  ) values (
    p_warehouse_id, 'DRAFT',
    p_actor_name, p_device_name, p_device_identifier
  ) returning * into v_count;

  if p_lines is not null and jsonb_typeof(p_lines) = 'array' then
    for v_line in select value from jsonb_array_elements(p_lines)
    loop
      v_product_id := (v_line ->> 'product_id')::uuid;
      v_expected_qty := (v_line ->> 'expected_quantity')::integer;

      insert into public.inventory_count_lines (
        count_id, product_id, expected_quantity,
        created_by, created_device_name, created_device_identifier
      ) values (
        v_count.id, v_product_id, v_expected_qty,
        p_actor_name, p_device_name, p_device_identifier
      );
    end loop;
  end if;

  return v_count;
end;
$$;

revoke all on function public.create_inventory_count(
  uuid, text, text, text, jsonb
) from public;
grant execute on function public.create_inventory_count(
  uuid, text, text, text, jsonb
) to anon, authenticated;

-- 3. RPC para agregar/reemplazar líneas en un conteo
create or replace function public.save_inventory_count_lines(
  p_count_id uuid,
  p_lines jsonb,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_line jsonb;
  v_product_id uuid;
  v_expected_qty integer;
begin
  if not exists (select 1 from public.inventory_counts where id = p_count_id) then
    raise exception using errcode = 'P0001', message = 'COUNT_NOT_FOUND';
  end if;

  -- Reemplazar todas las líneas (borra las existentes e inserta nuevas)
  delete from public.inventory_count_lines where count_id = p_count_id;

  if p_lines is not null and jsonb_typeof(p_lines) = 'array' then
    for v_line in select value from jsonb_array_elements(p_lines)
    loop
      v_product_id := (v_line ->> 'product_id')::uuid;
      v_expected_qty := (v_line ->> 'expected_quantity')::integer;

      insert into public.inventory_count_lines (
        count_id, product_id, expected_quantity,
        created_by, created_device_name, created_device_identifier
      ) values (
        p_count_id, v_product_id, v_expected_qty,
        p_actor_name, p_device_name, p_device_identifier
      );
    end loop;
  end if;
end;
$$;

revoke all on function public.save_inventory_count_lines(uuid, jsonb, text, text, text) from public;
grant execute on function public.save_inventory_count_lines(uuid, jsonb, text, text, text) to anon, authenticated;

-- 4. RPC para marcar líneas como revisadas
create or replace function public.review_inventory_count_line(
  p_line_id uuid,
  p_counted_quantity integer,
  p_notes text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.inventory_count_lines
     set counted_quantity = p_counted_quantity,
         reviewed = true,
         notes = nullif(trim(p_notes), '')
   where id = p_line_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'LINE_NOT_FOUND';
  end if;
end;
$$;

revoke all on function public.review_inventory_count_line(uuid, integer, text, text, text, text) from public;
grant execute on function public.review_inventory_count_line(uuid, integer, text, text, text, text) to anon, authenticated;

-- 5. RPC para pasar conteo a REVIEW (listo para confirmar)
create or replace function public.submit_inventory_count_for_review(
  p_count_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.inventory_counts
     set status = 'REVIEW'
   where id = p_count_id and status = 'DRAFT';
  if not found then
    raise exception using errcode = 'P0001', message = 'COUNT_NOT_DRAFT';
  end if;
end;
$$;

revoke all on function public.submit_inventory_count_for_review(uuid, text, text, text) from public;
grant execute on function public.submit_inventory_count_for_review(uuid, text, text, text) to anon, authenticated;