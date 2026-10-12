-- Sales documents select a warehouse, not a physical location. Keep the
-- legacy location argument on public RPC signatures for deployed clients,
-- but ignore it and allocate stock across sellable locations atomically.
create or replace function public.allocate_sales_dispatch_from_warehouse(
  p_document_id uuid,
  p_warehouse_id uuid,
  p_lines jsonb,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_line jsonb;
  v_balance record;
  v_remaining integer;
  v_available integer;
  v_take integer;
begin
  if p_document_id is null or p_warehouse_id is null or p_lines is null
     or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  perform 1
    from public.inventory_balances b
    join public.inventory_locations l on l.id = b.location_id
   where b.warehouse_id = p_warehouse_id
     and l.is_active and l.stock_role = 'SELLABLE'
     and b.product_id in (
       select (value->>'product_id')::uuid from jsonb_array_elements(p_lines)
     )
   order by b.product_id, b.location_id
   for update of b;

  for v_line in
    select jsonb_build_object('product_id', requested.product_id,
                              'quantity', sum(requested.quantity)::integer)
      from (
        select (value->>'product_id')::uuid as product_id,
               (value->>'quantity')::integer as quantity
          from jsonb_array_elements(p_lines)
      ) requested
     group by requested.product_id
  loop
    if (v_line->>'quantity')::integer <= 0 or not exists (
      select 1 from public.products p
       where p.id = (v_line->>'product_id')::uuid and p.is_active
    ) then
      raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
    end if;
    select coalesce(sum(greatest(b.quantity - b.reserved_quantity, 0)), 0)::integer
      into v_available
      from public.inventory_balances b
      join public.inventory_locations l on l.id = b.location_id
     where b.product_id = (v_line->>'product_id')::uuid
       and b.warehouse_id = p_warehouse_id
       and l.is_active and l.stock_role = 'SELLABLE';
    if v_available < (v_line->>'quantity')::integer then
      raise exception using errcode = 'P0001', message = 'INSUFFICIENT_STOCK';
    end if;
  end loop;

  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_remaining := (v_line->>'quantity')::integer;
    if v_remaining <= 0 then
      raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
    end if;
    insert into public.inventory_document_lines(document_id, product_id, quantity)
    values (p_document_id, (v_line->>'product_id')::uuid, -v_remaining);

    for v_balance in
      select b.location_id, b.quantity, b.reserved_quantity,
             l.is_default, l.code
        from public.inventory_balances b
        join public.inventory_locations l on l.id = b.location_id
       where b.product_id = (v_line->>'product_id')::uuid
         and b.warehouse_id = p_warehouse_id
         and l.is_active and l.stock_role = 'SELLABLE'
         and b.quantity > b.reserved_quantity
       order by l.is_default desc, l.code, b.location_id
       for update of b
    loop
      exit when v_remaining = 0;
      v_available := v_balance.quantity - v_balance.reserved_quantity;
      v_take := least(v_available, v_remaining);
      insert into public.inventory_transactions(
        product_id, warehouse_id, location_id, command_id, quantity,
        reason, actor_name, device_name, device_identifier, document_id
      ) values (
        (v_line->>'product_id')::uuid, p_warehouse_id, v_balance.location_id,
        extensions.gen_random_uuid(), -v_take, 'SALE', p_actor_name,
        p_device_name, p_device_identifier, p_document_id
      );
      v_remaining := v_remaining - v_take;
    end loop;
    if v_remaining > 0 then
      raise exception using errcode = 'P0001', message = 'INSUFFICIENT_STOCK';
    end if;
  end loop;
end;
$$;
revoke all on function public.allocate_sales_dispatch_from_warehouse(
  uuid, uuid, jsonb, text, text, text
) from public, anon, authenticated;

create or replace function public.create_order_with_reservation(
  p_customer_id uuid,
  p_customer_name text,
  p_currency_code char(3),
  p_exchange_rate numeric,
  p_notes text,
  p_agent_id uuid,
  p_quote_id uuid,
  p_lines jsonb,
  p_warehouse_id uuid,
  p_location_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_orders
language plpgsql security definer set search_path = '' as $$
declare
  v_order public.sales_orders%rowtype;
  v_line jsonb;
  v_total numeric := 0;
  v_document_id uuid;
begin
  if coalesce(btrim(p_customer_name), '') = '' or p_warehouse_id is null or p_lines is null
     or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;
  insert into public.sales_orders (
    order_number, customer_id, customer_name, status, total_amount,
    currency_code, exchange_rate, notes, agent_id, quote_id, created_by,
    created_device_name, created_device_identifier
  ) values (
    'PED-' || lpad(nextval('public.order_number_seq')::text, 6, '0'),
    p_customer_id, btrim(p_customer_name), 'CONFIRMED', v_total,
    p_currency_code, p_exchange_rate, p_notes, p_agent_id, p_quote_id,
    p_actor_name, p_device_name, p_device_identifier
  ) returning * into v_order;

  for v_line in select value from jsonb_array_elements(p_lines) loop
    insert into public.sales_order_lines (
      order_id, product_id, quantity, unit_price, discount_percent,
      total_price, product_sku, product_name
    ) values (
      v_order.id, (v_line->>'product_id')::uuid,
      (v_line->>'quantity')::integer, (v_line->>'unit_price')::numeric,
      coalesce((v_line->>'discount_percent')::numeric, 0),
      (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric,
      v_line->>'product_sku', v_line->>'product_name'
    );
  end loop;

  insert into public.inventory_documents (
    command_id, document_number, document_type, status, origin_warehouse_id,
    origin_location_id, external_reference, notes, confirmed_at
  ) values (
    extensions.gen_random_uuid(),
    'DES-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'),
    'SALE_DISPATCH', 'CONFIRMED', p_warehouse_id, null, v_order.order_number,
    'Pedido: ' || v_order.order_number, now()
  ) returning id into v_document_id;
  perform public.allocate_sales_dispatch_from_warehouse(
    v_document_id, p_warehouse_id, p_lines,
    p_actor_name, p_device_name, p_device_identifier
  );
  update public.sales_orders set inventory_document_id = v_document_id
   where id = v_order.id;
  select * into v_order from public.sales_orders where id = v_order.id;
  return v_order;
end;
$$;
revoke all on function public.create_order_with_reservation(
  uuid, text, char, numeric, text, uuid, uuid, jsonb, uuid, uuid, text, text, text
) from public, anon;
grant execute on function public.create_order_with_reservation(
  uuid, text, char, numeric, text, uuid, uuid, jsonb, uuid, uuid, text, text, text
) to authenticated;

create or replace function public.create_consignment(
  p_customer_id uuid,
  p_customer_name text,
  p_currency_code char(3),
  p_notes text,
  p_agent_id uuid,
  p_lines jsonb,
  p_warehouse_id uuid,
  p_location_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_consignments
language plpgsql security definer set search_path = '' as $$
declare
  v_consignment public.sales_consignments%rowtype;
  v_line jsonb;
  v_total numeric := 0;
  v_document_id uuid;
begin
  if coalesce(btrim(p_customer_name), '') = '' or p_warehouse_id is null or p_lines is null
     or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;
  insert into public.sales_consignments (
    consignment_number, customer_id, customer_name, status, total_amount,
    currency_code, notes, agent_id, created_by, created_device_name,
    created_device_identifier
  ) values (
    'CON-' || lpad(nextval('public.consignment_number_seq')::text, 6, '0'),
    p_customer_id, btrim(p_customer_name), 'SENT', v_total, p_currency_code,
    p_notes, p_agent_id, p_actor_name, p_device_name, p_device_identifier
  ) returning * into v_consignment;

  for v_line in select value from jsonb_array_elements(p_lines) loop
    insert into public.sales_consignment_lines (
      consignment_id, product_id, quantity, returned_quantity, unit_price,
      total_price, product_sku, product_name
    ) values (
      v_consignment.id, (v_line->>'product_id')::uuid,
      (v_line->>'quantity')::integer, 0, (v_line->>'unit_price')::numeric,
      (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric,
      v_line->>'product_sku', v_line->>'product_name'
    );
  end loop;

  insert into public.inventory_documents (
    command_id, document_number, document_type, status, origin_warehouse_id,
    origin_location_id, external_reference, notes, confirmed_at
  ) values (
    extensions.gen_random_uuid(),
    'CON-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'),
    'CONSIGNMENT', 'CONFIRMED', p_warehouse_id, null,
    v_consignment.consignment_number,
    'Consignación: ' || v_consignment.consignment_number, now()
  ) returning id into v_document_id;
  perform public.allocate_sales_dispatch_from_warehouse(
    v_document_id, p_warehouse_id, p_lines,
    p_actor_name, p_device_name, p_device_identifier
  );
  update public.sales_consignments set inventory_document_id = v_document_id
   where id = v_consignment.id;
  select * into v_consignment from public.sales_consignments
   where id = v_consignment.id;
  return v_consignment;
end;
$$;
revoke all on function public.create_consignment(
  uuid, text, char, text, uuid, jsonb, uuid, uuid, text, text, text
) from public, anon;
grant execute on function public.create_consignment(
  uuid, text, char, text, uuid, jsonb, uuid, uuid, text, text, text
) to authenticated;
