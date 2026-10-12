-- A full invoiced line can contain several condition allocations in one return.
-- Sellable units go back to source locations; damaged units go to quarantine.

alter table public.sales_return_lines
  add column if not exists source_inventory_location_id uuid
    references public.inventory_locations(id) on delete restrict;

update public.sales_return_lines rl
   set source_inventory_location_id = rl.inventory_location_id
  from public.inventory_locations l
 where rl.inventory_location_id = l.id
   and rl.condition = 'GOOD'
   and rl.source_inventory_location_id is null;

drop index if exists public.sales_returns_active_invoice_line_uidx;
create index if not exists sales_return_lines_active_invoice_line_idx
  on public.sales_return_lines(active_invoice_line_id)
  where active_invoice_line_id is not null;

create or replace function public.sales_preview_return(p_invoice_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_invoice public.sales_invoices%rowtype;
  v_warehouse_id uuid;
  v_paid numeric(18,2);
  v_outstanding numeric(18,2);
  v_lines jsonb;
begin
  select * into v_invoice from public.sales_invoices where id = p_invoice_id;
  if not found or v_invoice.status not in ('CONFIRMED', 'PAID') then
    raise exception using errcode = 'P0001', message = 'INVOICE_NOT_RETURNABLE';
  end if;
  if v_invoice.customer_id is null then
    raise exception using errcode = 'P0001', message = 'INVOICE_CUSTOMER_MISSING';
  end if;
  select origin_warehouse_id into v_warehouse_id
    from public.inventory_documents where id = v_invoice.inventory_document_id
      and document_type = 'SALE_DISPATCH';
  select coalesce(sum(pa.amount_applied), 0)::numeric(18,2) into v_paid
    from public.payment_applications pa join public.payments p on p.id = pa.payment_id
   where pa.invoice_id = p_invoice_id and p.status in ('CONFIRMED', 'REFUNDED')
     and coalesce(pa.currency_code, p.currency_code) = v_invoice.currency_code;
  v_outstanding := greatest(v_invoice.total_amount - v_paid, 0);
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', il.id, 'product_id', il.product_id, 'quantity', il.quantity,
    'unit_price', il.unit_price, 'discount_percent', il.discount_percent,
    'total_price', il.total_price, 'product_sku', il.product_sku,
    'product_name', il.product_name,
    'original_net_unit_price', round(il.total_price / il.quantity, 4),
    'available_quantity', case when exists (
      select 1 from public.sales_return_lines rl
      join public.sales_returns r on r.id = rl.return_id
      where rl.invoice_line_id = il.id and r.status <> 'CANCELLED'
    ) then 0 else il.quantity end
  ) order by il.id), '[]'::jsonb) into v_lines
    from public.sales_invoice_lines il where il.invoice_id = p_invoice_id;
  return jsonb_build_object(
    'invoice_id', v_invoice.id, 'invoice_number', v_invoice.invoice_number,
    'customer_id', v_invoice.customer_id, 'customer_name', v_invoice.customer_name,
    'currency_code', v_invoice.currency_code, 'total_amount', v_invoice.total_amount,
    'paid_amount', v_paid, 'outstanding_amount', v_outstanding,
    'lines', v_lines,
    'sellable_locations', (select coalesce(jsonb_agg(jsonb_build_object(
      'id', l.id, 'warehouse_id', l.warehouse_id, 'code', l.code, 'name', l.name
    ) order by l.is_default desc, l.code, l.id), '[]'::jsonb)
      from public.inventory_locations l
     where l.is_active and l.stock_role = 'SELLABLE'
       and l.warehouse_id = v_warehouse_id),
    'quarantine_locations', (select coalesce(jsonb_agg(jsonb_build_object(
      'id', l.id, 'warehouse_id', l.warehouse_id, 'code', l.code, 'name', l.name
    ) order by l.code, l.id), '[]'::jsonb)
      from public.inventory_locations l
     where l.is_active and l.stock_role = 'QUARANTINE'
       and l.warehouse_id = v_warehouse_id)
  );
end;
$$;

create or replace function public.sales_confirm_return(
  p_command_id uuid,
  p_invoice_id uuid,
  p_reason text,
  p_lines jsonb,
  p_resolution text,
  p_actor_name text,
  p_device_name text,
  p_device_identifier text
) returns public.sales_returns
language plpgsql security definer set search_path = '' as $$
declare
  v_hash bytea;
  v_existing public.sales_returns%rowtype;
  v_return public.sales_returns%rowtype;
  v_invoice public.sales_invoices%rowtype;
  v_invoice_line public.sales_invoice_lines%rowtype;
  v_inventory_doc public.inventory_documents%rowtype;
  v_quarantine public.inventory_locations%rowtype;
  v_group record;
  v_alloc record;
  v_source record;
  v_quantity integer;
  v_remaining integer;
  v_quantity_value_remaining integer;
  v_source_quantity integer;
  v_source_returned integer;
  v_legacy_remaining integer;
  v_source_available integer;
  v_take integer;
  v_price numeric(18,4);
  v_total numeric(18,2) := 0;
  v_value_remaining numeric(18,2);
  v_value_chunk numeric(18,2);
  v_paid numeric(18,2);
  v_outstanding numeric(18,2);
  v_debt_reduction numeric(18,2);
  v_excess numeric(18,2);
  v_inventory_id uuid;
  v_payment_effect_id uuid;
  v_return_line_id uuid;
  v_inventory_lines jsonb := '[]'::jsonb;
begin
  if p_command_id is null or p_invoice_id is null
     or length(btrim(coalesce(p_reason, ''))) not between 1 and 500
     or p_resolution not in ('REFUND', 'CUSTOMER_CREDIT')
     or jsonb_typeof(p_lines) is distinct from 'array'
     or jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_lines) e(value)
     where coalesce(e.value->>'quantity', '') !~ '^[1-9][0-9]*$'
        or e.value->>'condition' not in ('GOOD', 'DAMAGED')
        or nullif(e.value->>'invoice_line_id', '') is null
        or nullif(e.value->>'product_id', '') is null
  ) then
    raise exception using errcode = 'P0001', message = 'RETURN_QUANTITY_INVALID';
  end if;
  v_hash := extensions.digest(convert_to(jsonb_build_object(
    'invoice_id', p_invoice_id, 'reason', btrim(p_reason),
    'lines', p_lines, 'resolution', p_resolution
  )::text, 'UTF8'), 'sha256');
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_command_id::text, 0));
  select * into v_existing from public.sales_returns where command_id = p_command_id for update;
  if found then
    if (select payload_hash from public.sales_return_commands where command_id = p_command_id) <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_ID_CONFLICT';
    end if;
    return v_existing;
  end if;

  select * into v_invoice from public.sales_invoices where id = p_invoice_id for update;
  if not found or v_invoice.status not in ('CONFIRMED', 'PAID') then
    raise exception using errcode = 'P0001', message = 'INVOICE_NOT_RETURNABLE';
  end if;
  if v_invoice.customer_id is null then
    raise exception using errcode = 'P0001', message = 'INVOICE_CUSTOMER_MISSING';
  end if;
  select * into v_inventory_doc from public.inventory_documents
   where id = v_invoice.inventory_document_id and document_type = 'SALE_DISPATCH';
  if not found or v_inventory_doc.origin_warehouse_id is null then
    raise exception using errcode = 'P0001', message = 'INVOICE_INVENTORY_SOURCE_MISSING';
  end if;
  select * into v_quarantine from public.inventory_locations
   where warehouse_id = v_inventory_doc.origin_warehouse_id
     and is_active and stock_role = 'QUARANTINE'
   order by code, id limit 1 for update;
  if v_quarantine.id is null and exists (
    select 1 from jsonb_array_elements(p_lines) e(value)
     where e.value->>'condition' = 'DAMAGED'
  ) then
    raise exception using errcode = 'P0001', message = 'QUARANTINE_LOCATION_MISSING';
  end if;

  for v_group in
    select (e.value->>'invoice_line_id')::uuid as invoice_line_id,
           (e.value->>'product_id')::uuid as product_id,
           sum((e.value->>'quantity')::integer)::integer as quantity
      from jsonb_array_elements(p_lines) e(value)
     group by 1, 2
  loop
    select * into v_invoice_line from public.sales_invoice_lines
     where id = v_group.invoice_line_id and invoice_id = p_invoice_id for update;
    if not found or v_invoice_line.product_id <> v_group.product_id then
      raise exception using errcode = 'P0001', message = 'RETURN_LINE_NOT_IN_INVOICE';
    end if;
    if v_group.quantity <> v_invoice_line.quantity then
      raise exception using errcode = 'P0001', message = 'RETURN_QUANTITY_EXCEEDED';
    end if;
    if exists (
      select 1 from public.sales_return_lines rl
      join public.sales_returns r on r.id = rl.return_id
      where rl.invoice_line_id = v_invoice_line.id and r.status <> 'CANCELLED'
    ) then
      raise exception using errcode = 'P0001', message = 'RETURN_QUANTITY_EXCEEDED';
    end if;
    v_total := v_total + v_invoice_line.total_price;
  end loop;

  insert into public.sales_returns (
    return_number, invoice_id, customer_id, customer_name, status, total_amount,
    currency_code, reason, command_id, created_by, created_device_name,
    created_device_identifier, confirmed_at, financial_resolution
  ) values (
    'DEV-' || lpad(nextval('public.return_number_seq')::text, 6, '0'),
    p_invoice_id, v_invoice.customer_id, v_invoice.customer_name, 'CONFIRMED',
    v_total, v_invoice.currency_code, btrim(p_reason), p_command_id,
    p_actor_name, p_device_name, p_device_identifier, now(), p_resolution
  ) returning * into v_return;
  insert into public.sales_return_commands(command_id, payload_hash, entity_id)
    values (p_command_id, v_hash, v_return.id);

  for v_group in
    select (e.value->>'invoice_line_id')::uuid as invoice_line_id,
           (e.value->>'product_id')::uuid as product_id
      from jsonb_array_elements(p_lines) e(value)
     group by 1, 2 order by 1
  loop
    select * into v_invoice_line from public.sales_invoice_lines
     where id = v_group.invoice_line_id and invoice_id = p_invoice_id;
    v_price := round(v_invoice_line.total_price / v_invoice_line.quantity, 4);
    v_value_remaining := v_invoice_line.total_price;
    v_quantity_value_remaining := v_invoice_line.quantity;
    for v_alloc in
      select e.value->>'condition' as condition,
             (e.value->>'quantity')::integer as quantity
        from jsonb_array_elements(p_lines) e(value)
       where (e.value->>'invoice_line_id')::uuid = v_group.invoice_line_id
       order by case e.value->>'condition' when 'GOOD' then 0 else 1 end
    loop
      v_remaining := v_alloc.quantity;
      v_legacy_remaining := coalesce((
        select sum(rl.quantity)::integer
          from public.sales_return_lines rl
          join public.sales_returns r on r.id = rl.return_id
         where r.invoice_id = p_invoice_id and r.status <> 'CANCELLED'
           and r.id <> v_return.id and rl.product_id = v_group.product_id
           and rl.source_inventory_location_id is null
      ), 0);
      for v_source in
        select l.id as location_id, l.warehouse_id,
               sum(-t.quantity)::integer as sold_quantity,
               coalesce((
                 select sum(rl.quantity)::integer
                   from public.sales_return_lines rl
                   join public.sales_returns r on r.id = rl.return_id
                  where r.invoice_id = p_invoice_id and r.status <> 'CANCELLED'
                    and rl.product_id = v_group.product_id
                    and rl.source_inventory_location_id = l.id
               ), 0) as returned_quantity
          from public.inventory_transactions t
          join public.inventory_locations l on l.id = t.location_id
         where t.document_id = v_inventory_doc.id and t.product_id = v_group.product_id
           and t.reason = 'SALE' and t.quantity < 0
         group by l.id, l.warehouse_id, l.is_default, l.code
         order by l.is_default desc, l.code, l.id
      loop
        v_source_quantity := greatest(v_source.sold_quantity - v_source.returned_quantity, 0);
        v_take := least(v_legacy_remaining, v_source_quantity);
        v_legacy_remaining := v_legacy_remaining - v_take;
        v_source_available := v_source_quantity - v_take;
        exit when v_remaining = 0;
        if v_source_available <= 0 then continue; end if;
        v_take := least(v_remaining, v_source_available);
        if v_take = v_quantity_value_remaining then
          v_value_chunk := v_value_remaining;
        else
          v_value_chunk := least(
            v_value_remaining,
            round(v_invoice_line.total_price * v_take / v_invoice_line.quantity, 2)
          );
        end if;
        insert into public.sales_return_lines (
          return_id, invoice_line_id, product_id, quantity, unit_price, total_price,
          product_sku, product_name, condition, inventory_location_id,
          source_inventory_location_id, original_net_unit_price
        ) values (
          v_return.id, v_invoice_line.id, v_invoice_line.product_id, v_take,
          v_price, v_value_chunk, v_invoice_line.product_sku, v_invoice_line.product_name,
          v_alloc.condition,
          case when v_alloc.condition = 'GOOD' then v_source.location_id else v_quarantine.id end,
          v_source.location_id, v_price
        ) returning id into v_return_line_id;
        v_inventory_lines := v_inventory_lines || jsonb_build_array(jsonb_build_object(
          'sales_return_line_id', v_return_line_id,
          'invoice_line_id', v_invoice_line.id,
          'product_id', v_invoice_line.product_id,
          'quantity', v_take,
          'condition', v_alloc.condition,
          'location_id', case when v_alloc.condition = 'GOOD'
            then v_source.location_id else v_quarantine.id end
        ));
        v_remaining := v_remaining - v_take;
        v_quantity_value_remaining := v_quantity_value_remaining - v_take;
        v_value_remaining := v_value_remaining - v_value_chunk;
      end loop;
      if v_remaining > 0 then
        raise exception using errcode = 'P0001', message = 'INVOICE_INVENTORY_SOURCE_MISSING';
      end if;
    end loop;
  end loop;

  select coalesce(sum(pa.amount_applied), 0)::numeric(18,2) into v_paid
    from public.payment_applications pa join public.payments p on p.id = pa.payment_id
   where pa.invoice_id = p_invoice_id and p.status in ('CONFIRMED', 'REFUNDED')
     and coalesce(pa.currency_code, p.currency_code) = v_invoice.currency_code;
  v_outstanding := greatest(v_invoice.total_amount - v_paid, 0);
  v_debt_reduction := least(v_total, v_outstanding);
  v_excess := v_total - v_debt_reduction;
  if v_excess > 0 then
    v_payment_effect_id := public.payments_settle_sales_return(
      extensions.gen_random_uuid(), v_return.id, v_invoice.id, v_invoice.customer_id,
      v_invoice.customer_name, v_invoice.currency_code, v_excess, p_resolution,
      btrim(p_reason), p_actor_name, p_device_name, p_device_identifier
    );
  end if;
  v_inventory_id := public.inventory_receive_sales_return(
    extensions.gen_random_uuid(), v_return.id, v_return.return_number,
    v_inventory_lines, p_actor_name, p_device_name, p_device_identifier
  );
  update public.sales_returns set inventory_document_id = v_inventory_id,
    debt_reduction_amount = v_debt_reduction,
    financial_resolution_amount = v_excess, payment_effect_id = v_payment_effect_id
   where id = v_return.id returning * into v_return;
  perform public.audit_payments('sales', 'sales_returns', v_return.id, 'CONFIRM',
    p_actor_name, p_device_name, p_device_identifier, 'return', null,
    jsonb_build_object('invoice_id', p_invoice_id, 'amount', v_total,
      'debt_reduction', v_debt_reduction, 'resolution', p_resolution,
      'resolution_amount', v_excess, 'inventory_document_id', v_inventory_id)::text);
  return v_return;
end;
$$;

revoke all on function public.sales_preview_return(uuid) from public;
revoke all on function public.sales_preview_return(uuid) from anon;
grant execute on function public.sales_preview_return(uuid) to authenticated;
revoke all on function public.sales_confirm_return(uuid, uuid, text, jsonb, text, text, text, text)
  from public, anon;
grant execute on function public.sales_confirm_return(uuid, uuid, text, jsonb, text, text, text, text)
  to authenticated;
