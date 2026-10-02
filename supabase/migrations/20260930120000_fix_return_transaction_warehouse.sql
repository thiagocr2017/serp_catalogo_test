-- Corrección de almacén en movimientos de devolución
--
-- create_return crea el documento CUSTOMER_RETURN con
-- destination_warehouse/location (la mercadería vuelve a ese destino),
-- pero los movimientos de inventario leían origin_warehouse/location de
-- ese mismo documento, columnas nulas aquí. Toda devolución fallaba con
-- "null value in column warehouse_id". Se lee el destino del documento.

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
    values ((v_line->>'product_id')::uuid, (select destination_warehouse_id from public.inventory_documents where id = v_document_id), (select destination_location_id from public.inventory_documents where id = v_document_id), extensions.gen_random_uuid(), (v_line->>'quantity')::integer, 'RETURN', p_actor_name, p_device_name, p_device_identifier, v_document_id);
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
