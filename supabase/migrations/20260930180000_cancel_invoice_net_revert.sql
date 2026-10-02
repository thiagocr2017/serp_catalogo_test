-- Anular factura revierte solo lo no devuelto
--
-- Si la factura ya tiene devoluciones procesadas, anularla devolvía el
-- total otra vez (doble restauración). Ahora cada producto revierte su
-- cantidad facturada menos lo ya devuelto.

CREATE OR REPLACE FUNCTION public.cancel_sale_invoice(p_invoice_id uuid, p_reason text, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS sales_invoices
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_invoice public.sales_invoices%rowtype;
  v_line public.sales_invoice_lines%rowtype;
  v_document_id uuid;
begin
  select * into v_invoice from public.sales_invoices
  where id = p_invoice_id and status = 'CONFIRMED' for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'INVOICE_NOT_CANCELLABLE';
  end if;

  -- Crear documento de devolución
  select inventory_document_id into v_document_id from public.sales_invoices where id = p_invoice_id;

  if v_document_id is not null then
    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier, document_id
    )
    select
      l.product_id,
      d.origin_warehouse_id,
      d.origin_location_id,
      extensions.gen_random_uuid(),
      l.quantity - coalesce((
        select sum(rl.quantity)
          from public.sales_return_lines rl
          join public.sales_returns r on r.id = rl.return_id
         where r.invoice_id = p_invoice_id
           and r.status <> 'CANCELLED'
           and rl.product_id = l.product_id
      ), 0),
      'RETURN',
      p_actor_name, p_device_name, p_device_identifier,
      v_document_id
    from public.sales_invoice_lines l
    join public.inventory_documents d on d.id = v_document_id
    where l.invoice_id = p_invoice_id
      and l.quantity > coalesce((
        select sum(rl.quantity)
          from public.sales_return_lines rl
          join public.sales_returns r on r.id = rl.return_id
         where r.invoice_id = p_invoice_id
           and r.status <> 'CANCELLED'
           and rl.product_id = l.product_id
      ), 0);
  end if;

  -- Cancelar factura
  update public.sales_invoices
  set status = 'CANCELLED',
      cancelled_at = now(),
      notes = coalesce(notes, '') || ' [CANCELLED: ' || p_reason || ']',
      updated_by = p_actor_name,
      updated_device_name = p_device_name,
      updated_device_identifier = p_device_identifier
  where id = p_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$function$;

revoke all on function public.cancel_sale_invoice(uuid, text, text, text, text) from public;
grant execute on function public.cancel_sale_invoice(uuid, text, text, text, text) to anon, authenticated;
