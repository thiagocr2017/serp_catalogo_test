-- Facturas: contexto de cliente y salida por bodega con asignacion real por ubicacion.
alter table public.sales_return_lines
  add column if not exists invoice_line_id uuid
    references public.sales_invoice_lines(id);

-- Deterministically associate historical rows with repeated product lines.
with ranked_return_lines as (
  select rl.id as return_line_id, rl.return_id, rl.product_id,
         r.invoice_id,
         row_number() over (
           partition by rl.return_id, rl.product_id order by rl.id
         ) as line_number
    from public.sales_return_lines rl
    join public.sales_returns r on r.id = rl.return_id
   where rl.invoice_line_id is null
), ranked_invoice_lines as (
  select il.id as invoice_line_id, il.invoice_id, il.product_id,
         row_number() over (
           partition by il.invoice_id, il.product_id order by il.id
         ) as line_number
    from public.sales_invoice_lines il
), mapping as (
  select rr.return_line_id, il.invoice_line_id
    from ranked_return_lines rr
    join ranked_invoice_lines il using (invoice_id, product_id, line_number)
)
update public.sales_return_lines rl
   set invoice_line_id = mapping.invoice_line_id
  from mapping
 where rl.id = mapping.return_line_id;

create index if not exists sales_return_lines_invoice_line_idx
  on public.sales_return_lines(invoice_line_id)
  where invoice_line_id is not null;

drop function if exists public.create_sale_invoice_with_dispatch(
  uuid, text, character, numeric, text, jsonb, uuid, uuid, text, text, text
);

create or replace function public.create_sale_invoice_with_dispatch(
  p_command_id uuid,
  p_customer_id uuid,
  p_customer_name text,
  p_currency_code char(3),
  p_exchange_rate numeric,
  p_notes text,
  p_lines jsonb,
  p_warehouse_id uuid,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_invoices
language plpgsql security definer set search_path = '' as $$
declare
  v_hash bytea := extensions.digest(convert_to(jsonb_build_object(
    'operation', 'create_sale_invoice',
    'customer_id', p_customer_id,
    'customer_name', btrim(p_customer_name),
    'currency_code', p_currency_code,
    'exchange_rate', p_exchange_rate,
    'notes', p_notes,
    'lines', p_lines,
    'warehouse_id', p_warehouse_id
  )::text, 'UTF8'), 'sha256');
  v_existing public.sales_invoice_commands%rowtype;
  v_invoice public.sales_invoices%rowtype;
  v_invoice_id uuid;
  v_document_id uuid;
  v_line jsonb;
  v_balance record;
  v_available integer;
  v_to_allocate integer;
  v_total numeric := 0;
  v_unit numeric;
  v_quantity integer;
begin
  if p_customer_id is null or btrim(coalesce(p_customer_name, '')) = ''
     or p_exchange_rate is null or p_exchange_rate <= 0 or p_lines is null
     or jsonb_typeof(p_lines) is distinct from 'array'
     or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if not exists (select 1 from public.customers c where c.id = p_customer_id and c.is_active) then
    raise exception using errcode = 'P0001', message = 'CUSTOMER_INACTIVE';
  end if;
  if not exists (select 1 from public.warehouses w where w.id = p_warehouse_id and w.is_active) then
    raise exception using errcode = 'P0001', message = 'WAREHOUSE_INACTIVE';
  end if;

  insert into public.sales_invoice_commands(command_id, payload_hash)
  values (p_command_id, v_hash) on conflict do nothing
  returning command_id into v_invoice_id;
  if v_invoice_id is null then
    select * into v_existing from public.sales_invoice_commands
      where command_id = p_command_id for update;
    if v_existing.payload_hash <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_PAYLOAD_MISMATCH';
    end if;
    if v_existing.entity_id is null then
      raise exception using errcode = 'P0001', message = 'COMMAND_INCOMPLETE';
    end if;
    select * into v_invoice from public.sales_invoices where id = v_existing.entity_id;
    return v_invoice;
  end if;

  -- Lock every relevant balance in deterministic order before validating totals.
  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_quantity := (v_line->>'quantity')::integer;
    v_unit := (v_line->>'unit_price')::numeric;
    if v_quantity is null or v_unit is null or v_quantity <= 0 or v_unit <= 0
       or coalesce((v_line->>'discount_percent')::numeric, 0) < 0
       or coalesce((v_line->>'discount_percent')::numeric, 0) > 100 then
      raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
    end if;
    if not exists (select 1 from public.products p where p.id = (v_line->>'product_id')::uuid and p.is_active) then
      raise exception using errcode = 'P0001', message = 'PRODUCT_INACTIVE';
    end if;
    v_total := v_total + round(
      v_quantity * v_unit * (1 - coalesce((v_line->>'discount_percent')::numeric, 0) / 100), 2
    );
  end loop;

  perform 1
    from public.inventory_balances b
    join public.inventory_locations l on l.id = b.location_id
   where b.warehouse_id = p_warehouse_id and l.is_active
     and b.product_id in (
       select (value->>'product_id')::uuid from jsonb_array_elements(p_lines)
     )
   order by b.product_id, b.location_id
   for update of b;

  for v_line in
    select jsonb_build_object(
      'product_id', requested.product_id,
      'quantity', sum(requested.quantity)::integer
    )
    from (
      select (value->>'product_id')::uuid as product_id,
             (value->>'quantity')::integer as quantity
        from jsonb_array_elements(p_lines)
    ) requested
    group by requested.product_id
  loop
    v_quantity := (v_line->>'quantity')::integer;
    select coalesce(sum(greatest(b.quantity - b.reserved_quantity, 0)), 0)::integer
      into v_available
      from public.inventory_balances b
      join public.inventory_locations l on l.id = b.location_id
     where b.product_id = (v_line->>'product_id')::uuid
       and b.warehouse_id = p_warehouse_id and l.is_active;
    if v_available < v_quantity then
      raise exception using errcode = 'P0001', message = 'INSUFFICIENT_STOCK';
    end if;
  end loop;

  insert into public.sales_invoices (
    invoice_number, customer_id, customer_name, status, total_amount,
    currency_code, exchange_rate, notes, created_by,
    created_device_name, created_device_identifier, confirmed_at
  ) values (
    'FAC-' || lpad(nextval('public.sales_invoice_number_seq')::text, 6, '0'),
    p_customer_id, btrim(p_customer_name), 'CONFIRMED', v_total,
    p_currency_code, p_exchange_rate, p_notes, p_actor_name,
    p_device_name, p_device_identifier, now()
  ) returning * into v_invoice;

  insert into public.inventory_documents (
    command_id, document_number, document_type, status,
    origin_warehouse_id, origin_location_id, external_reference, notes, confirmed_at
  ) values (
    extensions.gen_random_uuid(),
    'DES-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'),
    'SALE_DISPATCH', 'CONFIRMED', p_warehouse_id, null,
    v_invoice.invoice_number, 'Factura: ' || v_invoice.invoice_number, now()
  ) returning id into v_document_id;

  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_quantity := (v_line->>'quantity')::integer;
    insert into public.sales_invoice_lines (
      invoice_id, product_id, quantity, unit_price, discount_percent,
      total_price, product_sku, product_name
    ) values (
      v_invoice.id, (v_line->>'product_id')::uuid, v_quantity,
      (v_line->>'unit_price')::numeric,
      coalesce((v_line->>'discount_percent')::numeric, 0),
      round(v_quantity * (v_line->>'unit_price')::numeric *
        (1 - coalesce((v_line->>'discount_percent')::numeric, 0) / 100), 2),
      v_line->>'product_sku', v_line->>'product_name'
    );
    insert into public.inventory_document_lines(document_id, product_id, quantity)
    values (v_document_id, (v_line->>'product_id')::uuid, -v_quantity);

    v_to_allocate := v_quantity;
    for v_balance in
      select b.location_id, b.quantity, b.reserved_quantity, l.is_default, l.code
        from public.inventory_balances b
        join public.inventory_locations l on l.id = b.location_id
       where b.product_id = (v_line->>'product_id')::uuid
         and b.warehouse_id = p_warehouse_id and l.is_active
         and b.quantity > b.reserved_quantity
       order by l.is_default desc, l.code, b.location_id
       for update of b
    loop
      exit when v_to_allocate = 0;
      v_available := v_balance.quantity - v_balance.reserved_quantity;
      v_unit := least(v_available, v_to_allocate);
      insert into public.inventory_transactions (
        product_id, warehouse_id, location_id, command_id, quantity, reason,
        actor_name, device_name, device_identifier, document_id
      ) values (
        (v_line->>'product_id')::uuid, p_warehouse_id, v_balance.location_id,
        extensions.gen_random_uuid(), -v_unit::integer, 'SALE',
        p_actor_name, p_device_name, p_device_identifier, v_document_id
      );
      v_to_allocate := v_to_allocate - v_unit::integer;
    end loop;
    if v_to_allocate > 0 then
      raise exception using errcode = 'P0001', message = 'INSUFFICIENT_STOCK';
    end if;
  end loop;

  update public.sales_invoices set inventory_document_id = v_document_id where id = v_invoice.id;
  update public.sales_invoice_commands set entity_id = v_invoice.id where command_id = p_command_id;
  perform public.audit_payments('sales', 'sales_invoices', v_invoice.id, 'CREATE',
    p_actor_name, p_device_name, p_device_identifier, 'invoice', null, v_invoice.total_amount::text);
  select * into v_invoice from public.sales_invoices where id = v_invoice.id;
  return v_invoice;
end;
$$;

revoke all on function public.create_sale_invoice_with_dispatch(
  uuid, uuid, text, char, numeric, text, jsonb, uuid, text, text, text
) from public;
grant execute on function public.create_sale_invoice_with_dispatch(
  uuid, uuid, text, char, numeric, text, jsonb, uuid, text, text, text
) to anon, authenticated;

create or replace function public.cancel_sale_invoice(
  p_invoice_id uuid,
  p_reason text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_invoices
language plpgsql security definer set search_path = '' as $$
declare
  v_invoice public.sales_invoices%rowtype;
  v_document_id uuid;
  v_sale record;
  v_previous_product_id uuid;
  v_returned_remaining integer := 0;
  v_returned integer;
  v_pending integer;
begin
  select * into v_invoice from public.sales_invoices
   where id = p_invoice_id and status = 'CONFIRMED' for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'INVOICE_NOT_CANCELLABLE';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception using errcode = 'P0001', message = 'CANCELLATION_REASON_REQUIRED';
  end if;
  v_document_id := v_invoice.inventory_document_id;
  if v_document_id is not null then
    for v_sale in
      select t.product_id, t.warehouse_id, t.location_id,
             -sum(t.quantity)::integer as sold_quantity
        from public.inventory_transactions t
       where t.document_id = v_document_id and t.reason = 'SALE'
       group by t.product_id, t.warehouse_id, t.location_id
       order by t.product_id, t.location_id
    loop
      if v_previous_product_id is distinct from v_sale.product_id then
        select coalesce(sum(rl.quantity), 0)::integer into v_returned_remaining
          from public.sales_return_lines rl
          join public.sales_returns r on r.id = rl.return_id
          join public.sales_invoice_lines il on il.id = rl.invoice_line_id
          where r.invoice_id = p_invoice_id and r.status <> 'CANCELLED'
           and il.product_id = v_sale.product_id;
        v_previous_product_id := v_sale.product_id;
      end if;
      v_returned := least(v_sale.sold_quantity, v_returned_remaining);
      v_returned_remaining := v_returned_remaining - v_returned;
      v_pending := v_sale.sold_quantity - v_returned;
      if v_pending > 0 then
        insert into public.inventory_transactions (
          product_id, warehouse_id, location_id, command_id, quantity, reason,
          actor_name, device_name, device_identifier, document_id
        ) values (
          v_sale.product_id, v_sale.warehouse_id, v_sale.location_id,
          extensions.gen_random_uuid(), v_pending, 'RETURN',
          p_actor_name, p_device_name, p_device_identifier, v_document_id
        );
      end if;
    end loop;
  end if;
  update public.sales_invoices
     set status = 'CANCELLED', cancelled_at = now(),
         notes = concat_ws(' ', nullif(notes, ''), '[CANCELLED: ' || btrim(p_reason) || ']'),
         updated_by = p_actor_name, updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_invoice_id returning * into v_invoice;
  return v_invoice;
end;
$$;

revoke all on function public.cancel_sale_invoice(uuid, text, text, text, text) from public;
grant execute on function public.cancel_sale_invoice(uuid, text, text, text, text) to anon, authenticated;
