-- Preserve inventory already received by legacy returns whose invoice-line
-- association cannot be reconstructed from their old payload.
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
         where r.invoice_id = p_invoice_id and r.status <> 'CANCELLED'
           and (
             (rl.invoice_line_id is null and rl.product_id = v_sale.product_id)
             or exists (
               select 1 from public.sales_invoice_lines il
                where il.id = rl.invoice_line_id
                  and il.product_id = v_sale.product_id
             )
           );
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
