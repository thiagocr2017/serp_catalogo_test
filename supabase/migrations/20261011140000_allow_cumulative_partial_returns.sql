alter table public.sales_return_lines
  add column if not exists condition_note text;

create or replace function public.sales_preview_return(p_invoice_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_invoice public.sales_invoices%rowtype;
  v_warehouse_id uuid;
  v_paid numeric(18,2);
  v_previously_reduced numeric(18,2);
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
  select coalesce(sum(r.debt_reduction_amount), 0)::numeric(18,2)
    into v_previously_reduced from public.sales_returns r
   where r.invoice_id = p_invoice_id and r.status <> 'CANCELLED';
  v_outstanding := greatest(v_outstanding - v_previously_reduced, 0);
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', il.id, 'product_id', il.product_id, 'quantity', il.quantity,
    'unit_price', il.unit_price, 'discount_percent', il.discount_percent,
    'total_price', il.total_price, 'product_sku', il.product_sku,
    'product_name', il.product_name,
    'original_net_unit_price', round(il.total_price / il.quantity, 4),
    'returned_quantity', returned.quantity,
    'available_quantity', greatest(il.quantity - returned.quantity, 0)
  ) order by il.id), '[]'::jsonb) into v_lines
    from public.sales_invoice_lines il
    cross join lateral (
      select coalesce(sum(rl.quantity), 0)::integer as quantity
        from public.sales_return_lines rl
        join public.sales_returns r on r.id = rl.return_id
       where r.invoice_id = p_invoice_id and r.status <> 'CANCELLED'
         and (rl.invoice_line_id = il.id or (
           rl.invoice_line_id is null and rl.product_id = il.product_id
           and exists (
             select 1 from public.sales_return_lines legacy
             join public.sales_returns lr on lr.id = legacy.return_id
             where lr.invoice_id = p_invoice_id and lr.status <> 'CANCELLED'
               and legacy.invoice_line_id is null and legacy.product_id = il.product_id
           ) and not exists (
             select 1 from public.sales_invoice_lines prior
             where prior.invoice_id = p_invoice_id and prior.product_id = il.product_id
               and prior.id < il.id
           )
         ))
    ) returned
   where il.invoice_id = p_invoice_id;
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
  v_available integer;
  v_remaining integer;
  v_current_quantity integer;
  v_previous_quantity integer;
  v_take integer;
  v_price numeric(18,4);
  v_total numeric(18,2) := 0;
  v_line_return_total numeric(18,2);
  v_previous_value numeric(18,2);
  v_amount_remaining numeric(18,2);
  v_quantity_amount_remaining integer;
  v_amount_chunk numeric(18,2);
  v_paid numeric(18,2);
  v_previously_reduced numeric(18,2);
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
        or (e.value->>'condition' = 'DAMAGED'
            and length(btrim(coalesce(e.value->>'condition_note', ''))) = 0)
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
  if exists (select 1 from public.sales_return_commands where command_id = p_command_id) then
    raise exception using errcode = 'P0001', message = 'COMMAND_ID_CONFLICT';
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
     group by 1, 2 order by 1
  loop
    select * into v_invoice_line from public.sales_invoice_lines
     where id = v_group.invoice_line_id and invoice_id = p_invoice_id for update;
    if not found or v_invoice_line.product_id <> v_group.product_id then
      raise exception using errcode = 'P0001', message = 'RETURN_LINE_NOT_IN_INVOICE';
    end if;
    select coalesce(sum(rl.quantity), 0)::integer,
           coalesce(sum(rl.total_price), 0)::numeric(18,2)
      into v_previous_quantity, v_previous_value
      from public.sales_return_lines rl
      join public.sales_returns r on r.id = rl.return_id
     where rl.invoice_line_id = v_invoice_line.id and r.status <> 'CANCELLED';
    if exists (
      select 1 from public.sales_return_lines rl
      join public.sales_returns r on r.id = rl.return_id
      where rl.invoice_line_id is null and rl.product_id = v_invoice_line.product_id
        and r.invoice_id = p_invoice_id and r.status <> 'CANCELLED'
        and not exists (
          select 1 from public.sales_invoice_lines earlier
          where earlier.invoice_id = p_invoice_id
            and earlier.product_id = v_invoice_line.product_id
            and earlier.id < v_invoice_line.id
        )
    ) then
      select coalesce(sum(rl.quantity), 0)::integer,
             coalesce(sum(rl.total_price), 0)::numeric(18,2)
        into v_current_quantity, v_line_return_total
        from public.sales_return_lines rl
        join public.sales_returns r on r.id = rl.return_id
       where rl.invoice_line_id is null and rl.product_id = v_invoice_line.product_id
         and r.invoice_id = p_invoice_id and r.status <> 'CANCELLED';
      v_previous_quantity := v_previous_quantity + v_current_quantity;
      v_previous_value := v_previous_value + v_line_return_total;
    end if;
    if v_group.quantity > v_invoice_line.quantity - v_previous_quantity then
      raise exception using errcode = 'P0001', message = 'RETURN_QUANTITY_EXCEEDED';
    end if;
    v_line_return_total := round(
      v_invoice_line.total_price * (v_previous_quantity + v_group.quantity)
      / v_invoice_line.quantity, 2
    ) - v_previous_value;
    if v_line_return_total <= 0 then
      raise exception using errcode = 'P0001', message = 'RETURN_QUANTITY_INVALID';
    end if;
    v_total := v_total + v_line_return_total;
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
           (e.value->>'product_id')::uuid as product_id,
           sum((e.value->>'quantity')::integer)::integer as quantity
      from jsonb_array_elements(p_lines) e(value)
     group by 1, 2 order by 1
  loop
    select * into v_invoice_line from public.sales_invoice_lines
     where id = v_group.invoice_line_id and invoice_id = p_invoice_id;
    select coalesce(sum(rl.quantity), 0)::integer,
           coalesce(sum(rl.total_price), 0)::numeric(18,2)
      into v_previous_quantity, v_previous_value
      from public.sales_return_lines rl
      join public.sales_returns r on r.id = rl.return_id
     where rl.invoice_line_id = v_invoice_line.id and r.status <> 'CANCELLED';
    v_current_quantity := v_group.quantity;
    v_line_return_total := round(
      v_invoice_line.total_price * (v_previous_quantity + v_current_quantity)
      / v_invoice_line.quantity, 2
    ) - v_previous_value;
    v_price := round(v_invoice_line.total_price / v_invoice_line.quantity, 4);
    v_amount_remaining := v_line_return_total;
    v_quantity_amount_remaining := v_current_quantity;
    for v_alloc in
      select e.value->>'condition' as condition,
             (e.value->>'quantity')::integer as quantity,
             nullif(btrim(e.value->>'condition_note'), '') as condition_note
        from jsonb_array_elements(p_lines) e(value)
       where (e.value->>'invoice_line_id')::uuid = v_group.invoice_line_id
       order by case e.value->>'condition' when 'GOOD' then 0 else 1 end
    loop
      v_remaining := v_alloc.quantity;
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
        exit when v_remaining = 0;
        v_available := greatest(v_source.sold_quantity - v_source.returned_quantity, 0);
        if v_available <= 0 then continue; end if;
        v_take := least(v_remaining, v_available);
        if v_take = v_quantity_amount_remaining then
          v_amount_chunk := v_amount_remaining;
        else
          v_amount_chunk := least(v_amount_remaining,
            round(v_line_return_total * v_take / v_current_quantity, 2));
        end if;
        insert into public.sales_return_lines (
          return_id, invoice_line_id, product_id, quantity, unit_price, total_price,
          product_sku, product_name, condition, condition_note,
          inventory_location_id, source_inventory_location_id,
          original_net_unit_price
        ) values (
          v_return.id, v_invoice_line.id, v_invoice_line.product_id, v_take,
          v_price, v_amount_chunk, v_invoice_line.product_sku, v_invoice_line.product_name,
          v_alloc.condition, v_alloc.condition_note,
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
        v_quantity_amount_remaining := v_quantity_amount_remaining - v_take;
        v_amount_remaining := v_amount_remaining - v_amount_chunk;
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
  select coalesce(sum(r.debt_reduction_amount), 0)::numeric(18,2)
    into v_previously_reduced from public.sales_returns r
   where r.invoice_id = p_invoice_id and r.status <> 'CANCELLED'
     and r.id <> v_return.id;
  v_outstanding := greatest(v_invoice.total_amount - v_paid - v_previously_reduced, 0);
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
