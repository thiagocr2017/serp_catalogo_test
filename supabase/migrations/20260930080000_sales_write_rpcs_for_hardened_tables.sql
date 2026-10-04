-- RPCs de escritura para tablas de ventas endurecidas
--
-- El endurecimiento revocó INSERT/UPDATE/DELETE directos sobre customers,
-- sales_quotes, sales_orders y sales_consignment_lines (tablas sin
-- políticas RLS), pero la app todavía escribía con .update(...) desde los
-- data sources, lo que fallaba con 42501. Estas RPCs siguen el patrón del
-- módulo (SECURITY DEFINER + search_path = '') y devuelven la fila
-- completa que esperan los mappers de Dart.
--
-- Nota: el retorno de consignaciones solo registra cantidades y recalcula
-- returned_amount; los flujos de liquidación/estado quedan para el
-- trabajo pendiente de ventas (.specs/modules/sales/sdd-historical.md).

-- 1. update_customer
create or replace function public.update_customer(
  p_customer_id uuid,
  p_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_tax_id text,
  p_credit_limit numeric,
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

revoke all on function public.update_customer(uuid, text, text, text, text, text, numeric, text, text, text) from public;
grant execute on function public.update_customer(uuid, text, text, text, text, text, numeric, text, text, text) to anon, authenticated;

-- 2. deactivate_customer
create or replace function public.deactivate_customer(
  p_customer_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.customers
     set is_active = false,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_customer_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
end;
$$;

revoke all on function public.deactivate_customer(uuid, text, text, text) from public;
grant execute on function public.deactivate_customer(uuid, text, text, text) to anon, authenticated;

-- 3. update_quote_status
create or replace function public.update_quote_status(
  p_quote_id uuid,
  p_status text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_quotes
language plpgsql security definer set search_path = '' as $$
declare
  v public.sales_quotes%rowtype;
begin
  if p_status not in ('DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CONVERTED') then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  update public.sales_quotes
     set status = p_status,
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_quote_id
  returning * into v;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  return v;
end;
$$;

revoke all on function public.update_quote_status(uuid, text, text, text, text) from public;
grant execute on function public.update_quote_status(uuid, text, text, text, text) to anon, authenticated;

-- 4. cancel_order
create or replace function public.cancel_order(
  p_order_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_orders
language plpgsql security definer set search_path = '' as $$
declare
  v public.sales_orders%rowtype;
begin
  select * into v
    from public.sales_orders
   where id = p_order_id
     for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;

  -- El pedido descuenta stock al crearse; al anular se devuelve con un
  -- movimiento RETURN (el trigger lo aplica a saldos y stock).
  if v.status <> 'CANCELLED' then
    if v.inventory_document_id is not null then
      insert into public.inventory_transactions (
        product_id, warehouse_id, location_id, command_id, quantity, reason,
        actor_name, device_name, device_identifier, document_id
      )
      select
        l.product_id,
        d.origin_warehouse_id,
        d.origin_location_id,
        extensions.gen_random_uuid(),
        l.quantity,
        'RETURN',
        p_actor_name, p_device_name, p_device_identifier,
        v.inventory_document_id
      from public.sales_order_lines l
      join public.inventory_documents d on d.id = v.inventory_document_id
      where l.order_id = p_order_id;
    end if;

    update public.sales_orders
       set status = 'CANCELLED',
           cancelled_at = now(),
           updated_by = p_actor_name,
           updated_device_name = p_device_name,
           updated_device_identifier = p_device_identifier,
           updated_at = now()
     where id = p_order_id
    returning * into v;
  end if;

  return v;
end;
$$;

revoke all on function public.cancel_order(uuid, text, text, text) from public;
grant execute on function public.cancel_order(uuid, text, text, text) to anon, authenticated;

-- 5. register_consignment_return
create or replace function public.register_consignment_return(
  p_consignment_id uuid,
  p_product_id uuid,
  p_quantity integer,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_consignments
language plpgsql security definer set search_path = '' as $$
declare
  v_line public.sales_consignment_lines%rowtype;
  v_consignment public.sales_consignments%rowtype;
begin
  if p_quantity is null or p_quantity < 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  select * into v_line
    from public.sales_consignment_lines
   where consignment_id = p_consignment_id
     and product_id = p_product_id
     for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;
  if p_quantity > v_line.quantity then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  update public.sales_consignment_lines
     set returned_quantity = p_quantity
   where consignment_id = p_consignment_id
     and product_id = p_product_id;

  update public.sales_consignments
     set returned_amount = (
           select coalesce(sum(returned_quantity * unit_price), 0)
             from public.sales_consignment_lines
            where consignment_id = p_consignment_id
         ),
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier,
         updated_at = now()
   where id = p_consignment_id
  returning * into v_consignment;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;

  return v_consignment;
end;
$$;

revoke all on function public.register_consignment_return(uuid, uuid, integer, text, text, text) from public;
grant execute on function public.register_consignment_return(uuid, uuid, integer, text, text, text) to anon, authenticated;
