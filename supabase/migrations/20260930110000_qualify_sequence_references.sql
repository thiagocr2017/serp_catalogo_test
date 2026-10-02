-- Calificar secuencias con el esquema public (42P01)
--
-- Seis RPC usan nextval('..._seq') sin calificar el esquema mientras
-- ejecutan con search_path = ''. Con la ruta de búsqueda vacía esos
-- nombres no resuelven y la llamada falla con "relation ... does not
-- exist" después de validar, rompiendo los formularios de cotizaciones,
-- pedidos, devoluciones, consignaciones, facturas y confirmación de
-- pagos. Se califica cada secuencia como public.<nombre>.

CREATE OR REPLACE FUNCTION public.confirm_payment(p_payment_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS payments
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_payment public.payments%rowtype;
begin
  update public.payments
     set status = 'CONFIRMED',
         receipt_number = 'RC-' || lpad(nextval('public.payment_receipt_seq')::text, 6, '0'),
         updated_by = p_actor_name,
         updated_device_name = p_device_name,
         updated_device_identifier = p_device_identifier
   where id = p_payment_id and status = 'PENDING'
  returning * into v_payment;
  if not found then
    raise exception using errcode = 'P0001', message = 'PAYMENT_NOT_PENDING';
  end if;
  perform public.audit_payments('payments', 'payments', v_payment.id, 'CONFIRM', p_actor_name, p_device_name, p_device_identifier, 'status', 'PENDING', 'CONFIRMED');
  return v_payment;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_consignment(p_customer_id uuid, p_customer_name text, p_currency_code character, p_notes text, p_agent_id uuid, p_lines jsonb, p_warehouse_id uuid, p_location_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS sales_consignments
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_consignment public.sales_consignments%rowtype;
  v_line jsonb;
  v_total numeric := 0;
  v_document_id uuid;
begin
  if btrim(p_customer_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;

  insert into public.sales_consignments (consignment_number, customer_id, customer_name, status, total_amount, currency_code, notes, agent_id, created_by, created_device_name, created_device_identifier)
  values ('CON-' || lpad(nextval('public.consignment_number_seq')::text, 6, '0'), p_customer_id, btrim(p_customer_name), 'SENT', v_total, p_currency_code, p_notes, p_agent_id, p_actor_name, p_device_name, p_device_identifier)
  returning * into v_consignment;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_consignment_lines (consignment_id, product_id, quantity, returned_quantity, unit_price, total_price, product_sku, product_name)
    values (v_consignment.id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer, 0, (v_line->>'unit_price')::numeric, (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric, v_line->>'product_sku', v_line->>'product_name');
  end loop;

  -- Crear documento de inventario CONSIGNMENT
  insert into public.inventory_documents (command_id, document_number, document_type, status, origin_warehouse_id, origin_location_id, external_reference, notes, confirmed_at)
  values (extensions.gen_random_uuid(), 'CON-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'), 'CONSIGNMENT', 'CONFIRMED', p_warehouse_id, p_location_id, v_consignment.consignment_number, 'Consignación: ' || v_consignment.consignment_number, now())
  returning id into v_document_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_document_lines (document_id, product_id, quantity)
    values (v_document_id, (v_line->>'product_id')::uuid, -(v_line->>'quantity')::integer);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_transactions (product_id, warehouse_id, location_id, command_id, quantity, reason, actor_name, device_name, device_identifier, document_id)
    values ((v_line->>'product_id')::uuid, p_warehouse_id, p_location_id, extensions.gen_random_uuid(), -(v_line->>'quantity')::integer, 'SALE', p_actor_name, p_device_name, p_device_identifier, v_document_id);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    update public.inventory_balances set quantity = quantity - (v_line->>'quantity')::integer
    where product_id = (v_line->>'product_id')::uuid and location_id = p_location_id;
    update public.products set current_stock = current_stock - (v_line->>'quantity')::integer
    where id = (v_line->>'product_id')::uuid;
  end loop;

  update public.sales_consignments set inventory_document_id = v_document_id where id = v_consignment.id;

  return v_consignment;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_order_with_reservation(p_customer_id uuid, p_customer_name text, p_currency_code character, p_exchange_rate numeric, p_notes text, p_agent_id uuid, p_quote_id uuid, p_lines jsonb, p_warehouse_id uuid, p_location_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS sales_orders
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_order public.sales_orders%rowtype;
  v_line jsonb;
  v_total numeric := 0;
  v_document_id uuid;
begin
  if btrim(p_customer_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;

  insert into public.sales_orders (order_number, customer_id, customer_name, status, total_amount, currency_code, exchange_rate, notes, agent_id, quote_id, created_by, created_device_name, created_device_identifier)
  values ('PED-' || lpad(nextval('public.order_number_seq')::text, 6, '0'), p_customer_id, btrim(p_customer_name), 'CONFIRMED', v_total, p_currency_code, p_exchange_rate, p_notes, p_agent_id, p_quote_id, p_actor_name, p_device_name, p_device_identifier)
  returning * into v_order;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_order_lines (order_id, product_id, quantity, unit_price, discount_percent, total_price, product_sku, product_name)
    values (v_order.id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer, (v_line->>'unit_price')::numeric, coalesce((v_line->>'discount_percent')::numeric, 0), (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric, v_line->>'product_sku', v_line->>'product_name');
  end loop;

  -- Crear documento de inventario SALE_DISPATCH
  insert into public.inventory_documents (command_id, document_number, document_type, status, origin_warehouse_id, origin_location_id, external_reference, notes, confirmed_at)
  values (extensions.gen_random_uuid(), 'DES-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'), 'SALE_DISPATCH', 'CONFIRMED', p_warehouse_id, p_location_id, v_order.order_number, 'Pedido: ' || v_order.order_number, now())
  returning id into v_document_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_document_lines (document_id, product_id, quantity)
    values (v_document_id, (v_line->>'product_id')::uuid, -(v_line->>'quantity')::integer);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_transactions (product_id, warehouse_id, location_id, command_id, quantity, reason, actor_name, device_name, device_identifier, document_id)
    values ((v_line->>'product_id')::uuid, p_warehouse_id, p_location_id, extensions.gen_random_uuid(), -(v_line->>'quantity')::integer, 'SALE', p_actor_name, p_device_name, p_device_identifier, v_document_id);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    update public.inventory_balances set quantity = quantity - (v_line->>'quantity')::integer
    where product_id = (v_line->>'product_id')::uuid and location_id = p_location_id;
    update public.products set current_stock = current_stock - (v_line->>'quantity')::integer
    where id = (v_line->>'product_id')::uuid;
  end loop;

  update public.sales_orders set inventory_document_id = v_document_id where id = v_order.id;

  return v_order;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_quote(p_customer_id uuid, p_customer_name text, p_currency_code character, p_exchange_rate numeric, p_valid_until date, p_notes text, p_agent_id uuid, p_lines jsonb, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS sales_quotes
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_quote public.sales_quotes%rowtype;
  v_line jsonb;
  v_total numeric := 0;
begin
  if btrim(p_customer_name) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;
  if jsonb_array_length(p_lines) = 0 then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;

  insert into public.sales_quotes (quote_number, customer_id, customer_name, status, total_amount, currency_code, exchange_rate, valid_until, notes, agent_id, created_by, created_device_name, created_device_identifier)
  values ('COT-' || lpad(nextval('public.quote_number_seq')::text, 6, '0'), p_customer_id, btrim(p_customer_name), 'DRAFT', v_total, p_currency_code, p_exchange_rate, p_valid_until, p_notes, p_agent_id, p_actor_name, p_device_name, p_device_identifier)
  returning * into v_quote;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_quote_lines (quote_id, product_id, quantity, unit_price, discount_percent, total_price, product_sku, product_name)
    values (v_quote.id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer, (v_line->>'unit_price')::numeric, coalesce((v_line->>'discount_percent')::numeric, 0), (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric, v_line->>'product_sku', v_line->>'product_name');
  end loop;

  return v_quote;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_return(p_invoice_id uuid, p_customer_id uuid, p_customer_name text, p_reason text, p_lines jsonb, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS sales_returns
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_id uuid;
  v_return public.sales_returns%rowtype;
  v_line jsonb;
  v_total numeric := 0;
  v_document_id uuid;
begin
  if btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'INVALID_INPUT';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;

  insert into public.sales_returns (return_number, invoice_id, customer_id, customer_name, status, total_amount, reason, created_by, created_device_name, created_device_identifier)
  values ('DEV-' || lpad(nextval('public.return_number_seq')::text, 6, '0'), p_invoice_id, p_customer_id, btrim(p_customer_name), 'CONFIRMED', v_total, btrim(p_reason), p_actor_name, p_device_name, p_device_identifier)
  returning * into v_return;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_return_lines (return_id, product_id, quantity, unit_price, total_price, product_sku, product_name)
    values (v_return.id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer, (v_line->>'unit_price')::numeric, (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric, v_line->>'product_sku', v_line->>'product_name');
  end loop;

  -- Crear documento de inventario CUSTOMER_RETURN
  insert into public.inventory_documents (command_id, document_number, document_type, status, destination_warehouse_id, destination_location_id, external_reference, notes, confirmed_at)
  values (extensions.gen_random_uuid(), 'DEV-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'), 'CUSTOMER_RETURN', 'CONFIRMED', (select origin_warehouse_id from public.inventory_documents where id = (select inventory_document_id from public.sales_invoices where id = p_invoice_id)), (select origin_location_id from public.inventory_documents where id = (select inventory_document_id from public.sales_invoices where id = p_invoice_id)), v_return.return_number, 'Devolución: ' || v_return.return_number, now())
  returning id into v_document_id;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_document_lines (document_id, product_id, quantity)
    values (v_document_id, (v_line->>'product_id')::uuid, (v_line->>'quantity')::integer);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_transactions (product_id, warehouse_id, location_id, command_id, quantity, reason, actor_name, device_name, device_identifier, document_id)
    values ((v_line->>'product_id')::uuid, (select origin_warehouse_id from public.inventory_documents where id = v_document_id), (select origin_location_id from public.inventory_documents where id = v_document_id), extensions.gen_random_uuid(), (v_line->>'quantity')::integer, 'RETURN', p_actor_name, p_device_name, p_device_identifier, v_document_id);
  end loop;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    update public.inventory_balances set quantity = quantity + (v_line->>'quantity')::integer
    where product_id = (v_line->>'product_id')::uuid;
    update public.products set current_stock = current_stock + (v_line->>'quantity')::integer
    where id = (v_line->>'product_id')::uuid;
  end loop;

  update public.sales_returns set inventory_document_id = v_document_id where id = v_return.id;

  return v_return;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_sale_invoice_with_dispatch(p_command_id uuid, p_customer_name text, p_currency_code character, p_exchange_rate numeric, p_notes text, p_lines jsonb, p_warehouse_id uuid, p_location_id uuid, p_actor_name text, p_device_name text, p_device_identifier text)
 RETURNS sales_invoices
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_hash bytea := extensions.digest(convert_to(jsonb_build_object(
    'operation', 'create_sale_invoice',
    'customer_name', btrim(p_customer_name),
    'currency_code', p_currency_code,
    'lines', p_lines,
    'warehouse_id', p_warehouse_id,
    'location_id', p_location_id
  )::text, 'UTF8'), 'sha256');
  v_invoice_id uuid;
  v_invoice public.sales_invoices%rowtype;
  v_line jsonb;
  v_total numeric := 0;
  v_document_id uuid;
begin
  -- Idempotencia
  insert into public.sales_invoice_commands(command_id, payload_hash)
  values (p_command_id, v_hash) on conflict do nothing returning command_id into v_invoice_id;
  if v_invoice_id is null then
    select entity_id into v_invoice_id from public.sales_invoice_commands where command_id = p_command_id for update;
    if (select payload_hash from public.sales_invoice_commands where command_id = p_command_id) <> v_hash then
      raise exception using errcode = 'P0001', message = 'COMMAND_PAYLOAD_MISMATCH';
    end if;
    if v_invoice_id is null then
      raise exception using errcode = 'P0001', message = 'COMMAND_INCOMPLETE';
    end if;
    select * into v_invoice from public.sales_invoices where id = v_invoice_id;
    return v_invoice;
  end if;

  -- Calcular total
  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_total := v_total + ((v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric);
  end loop;

  -- Crear factura
  insert into public.sales_invoices (
    invoice_number, customer_name, status, total_amount, currency_code, exchange_rate, notes,
    created_by, created_device_name, created_device_identifier
  ) values (
    'FAC-' || lpad(nextval('public.sales_invoice_number_seq')::text, 6, '0'),
    btrim(p_customer_name),
    'CONFIRMED',
    v_total,
    p_currency_code,
    p_exchange_rate,
    p_notes,
    p_actor_name, p_device_name, p_device_identifier
  ) returning * into v_invoice;

  -- Crear líneas de factura
  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.sales_invoice_lines (
      invoice_id, product_id, quantity, unit_price, discount_percent, total_price, product_sku, product_name
    ) values (
      v_invoice.id,
      (v_line->>'product_id')::uuid,
      (v_line->>'quantity')::integer,
      (v_line->>'unit_price')::numeric,
      coalesce((v_line->>'discount_percent')::numeric, 0),
      (v_line->>'quantity')::integer * (v_line->>'unit_price')::numeric * (1 - coalesce((v_line->>'discount_percent')::numeric, 0) / 100),
      v_line->>'product_sku',
      v_line->>'product_name'
    );
  end loop;

  -- Crear documento de inventario SALE_DISPATCH
  insert into public.inventory_documents (
    command_id, document_number, document_type, status,
    origin_warehouse_id, origin_location_id,
    external_reference, notes, confirmed_at
  ) values (
    extensions.gen_random_uuid(),
    'DES-' || lpad(nextval('public.inventory_document_number_seq')::text, 6, '0'),
    'SALE_DISPATCH',
    'CONFIRMED',
    p_warehouse_id,
    p_location_id,
    v_invoice.invoice_number,
    'Factura: ' || v_invoice.invoice_number,
    now()
  ) returning id into v_document_id;

  -- Crear líneas del documento de inventario
  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_document_lines (document_id, product_id, quantity)
    values (v_document_id, (v_line->>'product_id')::uuid, -(v_line->>'quantity')::integer);
  end loop;

  -- Crear transacciones de inventario (SALE)
  for v_line in select * from jsonb_array_elements(p_lines) loop
    insert into public.inventory_transactions (
      product_id, warehouse_id, location_id, command_id, quantity, reason,
      actor_name, device_name, device_identifier, document_id
    ) values (
      (v_line->>'product_id')::uuid,
      p_warehouse_id,
      p_location_id,
      extensions.gen_random_uuid(),
      -(v_line->>'quantity')::integer,
      'SALE',
      p_actor_name, p_device_name, p_device_identifier,
      v_document_id
    );
  end loop;

  -- Actualizar stock
  for v_line in select * from jsonb_array_elements(p_lines) loop
    update public.inventory_balances
    set quantity = quantity - (v_line->>'quantity')::integer
    where product_id = (v_line->>'product_id')::uuid and location_id = p_location_id;

    update public.products
    set current_stock = current_stock - (v_line->>'quantity')::integer
    where id = (v_line->>'product_id')::uuid;
  end loop;

  -- Vincular documento a factura
  update public.sales_invoices set inventory_document_id = v_document_id where id = v_invoice.id;

  -- Marcar comando completado
  update public.sales_invoice_commands set entity_id = v_invoice.id where command_id = p_command_id;

  -- Auditoría
  perform public.audit_payments('sales', 'sales_invoices', v_invoice.id, 'CREATE', p_actor_name, p_device_name, p_device_identifier, 'invoice', null, v_invoice.total_amount::text);

  return v_invoice;
end;
$function$;
