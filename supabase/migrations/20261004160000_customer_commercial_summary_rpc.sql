-- Resumen Comercial y Alertas Reales de Cliente (Decisiones 34, 35, 36)
--
-- 1. RPC public.customer_commercial_summary(p_customer_id uuid)
--    Devuelve:
--    - last_purchase_at (timestamptz)
--    - total_invoiced (numeric)
--    - confirmed_orders_count (int)
--    - pending_orders_count (int)
--    - pending_quotes_count (int)
--    - pending_returns_count (int)
--    - pending_consignments_count (int)
--    - overdue_invoices_count (int)
--    - overdue_invoices_amount (numeric)
--    - frequent_products (jsonb): top productos por cantidad comprada
--
-- 2. Permisos para anon y authenticated sobre la función.

create or replace function public.customer_commercial_summary(p_customer_id uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_customer public.customers%rowtype;
  v_last_purchase_at timestamptz;
  v_total_invoiced numeric(18,2) := 0;
  v_confirmed_orders_count integer := 0;
  v_pending_orders_count integer := 0;
  v_pending_quotes_count integer := 0;
  v_pending_returns_count integer := 0;
  v_pending_consignments_count integer := 0;
  v_overdue_invoices_count integer := 0;
  v_overdue_invoices_amount numeric(18,2) := 0;
  v_frequent_products jsonb := '[]'::jsonb;
begin
  select * into v_customer from public.customers where id = p_customer_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'NOT_FOUND';
  end if;

  -- Última compra (de factura confirmada/pagada o pedido confirmado/despachado)
  select max(purchased_at) into v_last_purchase_at
  from (
    select confirmed_at as purchased_at
    from public.sales_invoices
    where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
      and status in ('CONFIRMED', 'PAID')
    union all
    select coalesce(confirmed_at, created_at) as purchased_at
    from public.sales_orders
    where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
      and status in ('CONFIRMED', 'RESERVED', 'DISPATCHED', 'DELIVERED')
  ) p;

  -- Total facturado confirmado/pagado
  select coalesce(sum(total_amount), 0) into v_total_invoiced
  from public.sales_invoices
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status in ('CONFIRMED', 'PAID');

  -- Pedidos confirmados / despachados
  select count(*)::integer into v_confirmed_orders_count
  from public.sales_orders
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status in ('CONFIRMED', 'RESERVED', 'DISPATCHED', 'DELIVERED');

  -- Documentos pendientes (Decision 34: no despachados, sin respuesta, sin procesar, sin liquidar)
  -- 1. Pedidos sin despachar (DRAFT o CONFIRMED/RESERVED)
  select count(*)::integer into v_pending_orders_count
  from public.sales_orders
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status in ('DRAFT', 'CONFIRMED', 'RESERVED');

  -- 2. Cotizaciones sin respuesta (SENT o DRAFT)
  select count(*)::integer into v_pending_quotes_count
  from public.sales_quotes
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status in ('DRAFT', 'SENT');

  -- 3. Devoluciones sin procesar (DRAFT)
  select count(*)::integer into v_pending_returns_count
  from public.sales_returns
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status = 'DRAFT';

  -- 4. Consignaciones sin liquidar (DRAFT, SENT, PARTIAL_RETURN)
  select count(*)::integer into v_pending_consignments_count
  from public.sales_consignments
  where (customer_id = p_customer_id or (customer_id is null and customer_name = v_customer.name))
    and status in ('DRAFT', 'SENT', 'PARTIAL_RETURN');

  -- Facturas vencidas (CONFIRMED con saldo no cubierto y creadas hace más de 30 días o si el cliente tiene días de crédito)
  -- Si el cliente es de crédito y tiene crédito_days > 0, se considera vencida tras credit_days días.
  select count(*)::integer, coalesce(sum(total_amount), 0)
    into v_overdue_invoices_count, v_overdue_invoices_amount
  from public.sales_invoices i
  where (i.customer_id = p_customer_id or (i.customer_id is null and i.customer_name = v_customer.name))
    and i.status = 'CONFIRMED'
    and now() > (i.created_at + make_interval(days => coalesce(v_customer.credit_days, 30)));

  -- Decision 36: "Productos que le gustan" = frecuentes por cantidad en facturas o pedidos
  select coalesce(jsonb_agg(sub order by sub.total_quantity desc), '[]'::jsonb)
  into v_frequent_products
  from (
    select
      lines.product_id,
      max(lines.product_name) as product_name,
      max(lines.product_sku) as product_sku,
      sum(lines.quantity)::integer as total_quantity,
      count(distinct lines.doc_id)::integer as purchase_count
    from (
      select il.invoice_id as doc_id, il.product_id, il.product_name, il.product_sku, il.quantity
      from public.sales_invoice_lines il
      join public.sales_invoices i on i.id = il.invoice_id
      where (i.customer_id = p_customer_id or (i.customer_id is null and i.customer_name = v_customer.name))
        and i.status in ('CONFIRMED', 'PAID')
      union all
      select ol.order_id as doc_id, ol.product_id, ol.product_name, ol.product_sku, ol.quantity
      from public.sales_order_lines ol
      join public.sales_orders o on o.id = ol.order_id
      where (o.customer_id = p_customer_id or (o.customer_id is null and o.customer_name = v_customer.name))
        and o.status <> 'CANCELLED'
    ) lines
    group by lines.product_id
    order by sum(lines.quantity) desc
    limit 5
  ) sub;

  return jsonb_build_object(
    'customer_id', p_customer_id,
    'last_purchase_at', v_last_purchase_at,
    'total_invoiced', v_total_invoiced,
    'confirmed_orders_count', v_confirmed_orders_count,
    'pending_orders_count', v_pending_orders_count,
    'pending_quotes_count', v_pending_quotes_count,
    'pending_returns_count', v_pending_returns_count,
    'pending_consignments_count', v_pending_consignments_count,
    'total_pending_documents', (v_pending_orders_count + v_pending_quotes_count + v_pending_returns_count + v_pending_consignments_count),
    'overdue_invoices_count', v_overdue_invoices_count,
    'overdue_invoices_amount', v_overdue_invoices_amount,
    'frequent_products', v_frequent_products
  );
end;
$$;

revoke all on function public.customer_commercial_summary(uuid) from public;
grant execute on function public.customer_commercial_summary(uuid) to anon, authenticated;
