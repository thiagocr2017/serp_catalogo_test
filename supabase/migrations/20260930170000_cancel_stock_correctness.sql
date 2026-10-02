-- Cierre del aplicador único de stock
--
-- cancel_sale_invoice revertía a mano ADEMÁS de insertar movimientos
-- RETURN (doble devolución) y sin filtro de ubicación. Se deja solo el
-- movimiento; el trigger aplica.
-- cancel_order solo cambiaba el estado sin devolver el stock que el
-- pedido descuenta al crearse: ahora inserta el movimiento RETURN (solo
-- si no estaba anulado) y el trigger lo aplica.

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
      l.quantity,
      'RETURN',
      p_actor_name, p_device_name, p_device_identifier,
      v_document_id
    from public.sales_invoice_lines l
    join public.inventory_documents d on d.id = v_document_id
    where l.invoice_id = p_invoice_id;
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
