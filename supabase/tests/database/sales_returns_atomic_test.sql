begin;

select plan(39);

insert into public.warehouses(id, code, name)
values ('81000000-0000-0000-0000-000000000001', 'RET-PG', 'Bodega devoluciones');
insert into public.inventory_locations(id, warehouse_id, code, name, stock_role)
values
 ('81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000001', 'SELL', 'Vendible', 'SELLABLE'),
 ('81000000-0000-0000-0000-000000000003', '81000000-0000-0000-0000-000000000001', 'QUAR', 'Cuarentena', 'QUARANTINE'),
 ('81000000-0000-0000-0000-000000000008', '81000000-0000-0000-0000-000000000001', 'SELL-2', 'Vendible 2', 'SELLABLE');
insert into public.categories(id, name)
values ('81000000-0000-0000-0000-000000000004', 'Categoria devoluciones');
insert into public.packaging_presentations(id, name, sort_order)
values ('81000000-0000-0000-0000-000000000007', 'Unidad pgTAP', 900)
on conflict do nothing;
insert into public.products(id, sku, name, description, category_id, unit_price,
  min_order_quantity, packaging_presentation_id, cbm_per_moq, factory_cost,
  current_stock, reorder_point, promo_price)
select '81000000-0000-0000-0000-000000000005', 'RET-PG-1', 'Producto devolución', '',
  '81000000-0000-0000-0000-000000000004', 50, 1, '81000000-0000-0000-0000-000000000007', 0, 0, 0, 0, 45;
insert into public.customers(id, name, is_active)
values ('81000000-0000-0000-0000-000000000006', 'Cliente devolución', true);

insert into public.sales_invoices(id, invoice_number, customer_id, customer_name,
  status, total_amount, currency_code)
values
 ('81000000-0000-0000-0000-000000000010', 'FAC-RET-PG-1', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 'CONFIRMED', 100, 'USD'),
 ('81000000-0000-0000-0000-000000000011', 'FAC-RET-PG-2', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 'CONFIRMED', 100, 'USD'),
 ('81000000-0000-0000-0000-000000000012', 'FAC-RET-PG-3', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 'CONFIRMED', 100, 'USD'),
 ('81000000-0000-0000-0000-000000000013', 'FAC-RET-PG-4', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 'CONFIRMED', 100, 'USD'),
 ('81000000-0000-0000-0000-000000000014', 'FAC-RET-PG-5', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 'CONFIRMED', 300, 'USD');
insert into public.sales_invoice_lines(id, invoice_id, product_id, quantity,
  unit_price, discount_percent, total_price, product_sku, product_name)
values
 ('81000000-0000-0000-0000-000000000020', '81000000-0000-0000-0000-000000000010', '81000000-0000-0000-0000-000000000005', 2, 50, 10, 90, 'RET-PG-1', 'Producto devolución'),
 ('81000000-0000-0000-0000-000000000021', '81000000-0000-0000-0000-000000000011', '81000000-0000-0000-0000-000000000005', 1, 50, 0, 50, 'RET-PG-1', 'Producto devolución'),
 ('81000000-0000-0000-0000-000000000022', '81000000-0000-0000-0000-000000000012', '81000000-0000-0000-0000-000000000005', 1, 50, 0, 50, 'RET-PG-1', 'Producto devolución'),
 ('81000000-0000-0000-0000-000000000023', '81000000-0000-0000-0000-000000000013', '81000000-0000-0000-0000-000000000005', 1, 50, 0, 50, 'RET-PG-1', 'Producto devolución'),
 ('81000000-0000-0000-0000-000000000024', '81000000-0000-0000-0000-000000000014', '81000000-0000-0000-0000-000000000005', 6, 50, 0, 300, 'RET-PG-1', 'Producto devolución');

insert into public.inventory_documents(id, command_id, document_number, document_type,
  status, origin_warehouse_id, external_reference, confirmed_at)
values
 ('81000000-0000-0000-0000-000000000040', '81000000-0000-0000-0000-000000000050', 'DES-RET-1', 'SALE_DISPATCH', 'CONFIRMED', '81000000-0000-0000-0000-000000000001', 'FAC-RET-PG-1', now()),
 ('81000000-0000-0000-0000-000000000041', '81000000-0000-0000-0000-000000000051', 'DES-RET-2', 'SALE_DISPATCH', 'CONFIRMED', '81000000-0000-0000-0000-000000000001', 'FAC-RET-PG-2', now()),
 ('81000000-0000-0000-0000-000000000042', '81000000-0000-0000-0000-000000000052', 'DES-RET-3', 'SALE_DISPATCH', 'CONFIRMED', '81000000-0000-0000-0000-000000000001', 'FAC-RET-PG-3', now()),
 ('81000000-0000-0000-0000-000000000043', '81000000-0000-0000-0000-000000000053', 'DES-RET-4', 'SALE_DISPATCH', 'CONFIRMED', '81000000-0000-0000-0000-000000000001', 'FAC-RET-PG-4', now()),
 ('81000000-0000-0000-0000-000000000044', '81000000-0000-0000-0000-000000000054', 'DES-RET-5', 'SALE_DISPATCH', 'CONFIRMED', '81000000-0000-0000-0000-000000000001', 'FAC-RET-PG-5', now());
update public.sales_invoices i set inventory_document_id = d.id
  from public.inventory_documents d where i.invoice_number = d.external_reference;

insert into public.inventory_transactions(product_id, warehouse_id, location_id,
  command_id, quantity, reason, device_name, device_identifier, document_id)
values
 ('81000000-0000-0000-0000-000000000005', '81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000060', 7, 'ADJUSTMENT', 'pgTAP', 'pgTAP', null),
 ('81000000-0000-0000-0000-000000000005', '81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000008', '81000000-0000-0000-0000-000000000061', 4, 'ADJUSTMENT', 'pgTAP', 'pgTAP', null),
 ('81000000-0000-0000-0000-000000000005', '81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000062', -2, 'SALE', 'pgTAP', 'pgTAP', '81000000-0000-0000-0000-000000000040'),
 ('81000000-0000-0000-0000-000000000005', '81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000063', -1, 'SALE', 'pgTAP', 'pgTAP', '81000000-0000-0000-0000-000000000041'),
 ('81000000-0000-0000-0000-000000000005', '81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000064', -1, 'SALE', 'pgTAP', 'pgTAP', '81000000-0000-0000-0000-000000000042'),
 ('81000000-0000-0000-0000-000000000005', '81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000065', -1, 'SALE', 'pgTAP', 'pgTAP', '81000000-0000-0000-0000-000000000043'),
 ('81000000-0000-0000-0000-000000000005', '81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000066', -2, 'SALE', 'pgTAP', 'pgTAP', '81000000-0000-0000-0000-000000000044'),
 ('81000000-0000-0000-0000-000000000005', '81000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000008', '81000000-0000-0000-0000-000000000067', -4, 'SALE', 'pgTAP', 'pgTAP', '81000000-0000-0000-0000-000000000044');
insert into public.payments(id, status, customer_id, customer_name, total_amount, currency_code)
values
 ('81000000-0000-0000-0000-000000000030', 'CONFIRMED', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 40, 'USD'),
 ('81000000-0000-0000-0000-000000000031', 'CONFIRMED', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 40, 'USD'),
 ('81000000-0000-0000-0000-000000000032', 'CONFIRMED', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 60, 'USD'),
 ('81000000-0000-0000-0000-000000000033', 'CONFIRMED', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 40, 'USD'),
 ('81000000-0000-0000-0000-000000000034', 'CONFIRMED', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 50, 'USD');
insert into public.payment_applications(payment_id, invoice_id, amount_applied, currency_code)
values
 ('81000000-0000-0000-0000-000000000030', '81000000-0000-0000-0000-000000000010', 40, 'USD'),
 ('81000000-0000-0000-0000-000000000031', '81000000-0000-0000-0000-000000000010', 40, 'USD'),
 ('81000000-0000-0000-0000-000000000032', '81000000-0000-0000-0000-000000000011', 60, 'USD'),
 ('81000000-0000-0000-0000-000000000033', '81000000-0000-0000-0000-000000000011', 40, 'USD'),
 ('81000000-0000-0000-0000-000000000034', '81000000-0000-0000-0000-000000000013', 50, 'USD');

set local role authenticated;

select is(public.sales_preview_return('81000000-0000-0000-0000-000000000010')->>'outstanding_amount', '20.00', 'preview calcula saldo pendiente desde aplicaciones confirmadas');
select is(public.sales_preview_return('81000000-0000-0000-0000-000000000010')->'lines'->0->>'available_quantity', '2', 'preview expone las unidades elegibles');
select lives_ok($$select public.sales_confirm_return('82000000-0000-0000-0000-000000000006', '81000000-0000-0000-0000-000000000010', 'Tres unidades dañadas', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000020","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"DAMAGED","condition_note":"Unidad quebrada"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')$$, 'permite devolver parcialmente una línea con motivo de daño');
select is(public.sales_preview_return('81000000-0000-0000-0000-000000000010')->'lines'->0->>'available_quantity', '1', 'preview deja el saldo no devuelto tras una devolución parcial');
select is((select condition_note from public.sales_return_lines where return_id = (select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000006')), 'Unidad quebrada', 'la nota de daño queda persistida');
select throws_ok($$select (public.sales_confirm_return('82000000-0000-0000-0000-000000000008', '81000000-0000-0000-0000-000000000013', 'Sin nota', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000023","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"DAMAGED"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')).id$$, 'P0001', 'RETURN_QUANTITY_INVALID', 'rechaza unidad dañada sin nota');

select lives_ok($$select public.sales_confirm_return(
 '82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000010',
 'Empaque abierto', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000020","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000002"}]',
 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')$$, 'confirmación crea devolución y efectos en una transacción');
select is((select total_amount from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001'), 45::numeric, 'devolución parcial usa la mitad del valor neto facturado');
select is((select debt_reduction_amount from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001'), 0::numeric, 'no vuelve a reducir deuda ya rebajada por la devolución previa');
select is((select financial_resolution_amount from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001'), 45::numeric, 'la segunda devolución liquida solo su excedente pagado');
select is((select sum(quantity)::integer from public.inventory_balances where product_id = '81000000-0000-0000-0000-000000000005' and location_id = '81000000-0000-0000-0000-000000000002'), 1, 'la unidad buena de la segunda devolución se recibe en ubicación vendible');
select is((select current_stock from public.products where id = '81000000-0000-0000-0000-000000000005'), 1, 'stock público incluye solo unidades buenas devueltas');
select ok((select count(*)::integer from public.refunds where sales_return_id = (select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001')) >= 1, 'reembolso se distribuye entre pagos elegibles');
select is((select sum(amount) from public.refunds where sales_return_id = (select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001')), 45::numeric, 'suma reembolsada iguala el excedente parcial');
select is(public.sales_preview_return('81000000-0000-0000-0000-000000000010')->'lines'->0->>'available_quantity', '0', 'la línea queda agotada después de dos devoluciones parciales');

select is((select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001'),
  (select (public.sales_confirm_return('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000010', 'Empaque abierto', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000020","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000002"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')).id), 'reintento devuelve el mismo documento');
select throws_ok($$select (public.sales_confirm_return('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000010', 'Otro motivo', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000020","product_id":"81000000-0000-0000-0000-000000000005","quantity":2,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000002"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')).id$$, 'P0001', 'COMMAND_ID_CONFLICT', 'mismo comando con payload distinto falla');
select throws_ok($$select (public.sales_confirm_return('82000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000010', 'Duplicado', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000020","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000002"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')).id$$, 'P0001', 'RETURN_QUANTITY_EXCEEDED', 'línea confirmada no se devuelve por segunda vez');

select lives_ok($$select public.sales_confirm_return(
 '82000000-0000-0000-0000-000000000003', '81000000-0000-0000-0000-000000000011',
 'Producto dañado', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000021","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"DAMAGED","condition_note":"Caja golpeada","location_id":"81000000-0000-0000-0000-000000000003"}]',
 'CUSTOMER_CREDIT', 'pgTAP', 'pgTAP', 'pgTAP')$$, 'dañado ingresa a cuarentena y excedente se registra como crédito');
select is((select sum(quantity)::integer from public.inventory_balances where product_id = '81000000-0000-0000-0000-000000000005' and location_id = '81000000-0000-0000-0000-000000000003'), 2, 'cuarentena conserva las unidades físicas dañadas');
select is((select current_stock from public.products where id = '81000000-0000-0000-0000-000000000005'), 1, 'cuarentena no aumenta stock vendible');
select is((select amount from public.customer_credit_entries where sales_return_id = (select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000003')), 50::numeric, 'crédito se limita al excedente pagado');

select lives_ok($$select public.sales_confirm_return(
 '82000000-0000-0000-0000-000000000007', '81000000-0000-0000-0000-000000000014',
 'Tres unidades dañadas', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000024","product_id":"81000000-0000-0000-0000-000000000005","quantity":3,"condition":"DAMAGED","condition_note":"Tres unidades quebradas"}]',
 'CUSTOMER_CREDIT', 'pgTAP', 'pgTAP', 'pgTAP')$$, 'acepta la primera devolución parcial de tres unidades dañadas');
select is(public.sales_preview_return('81000000-0000-0000-0000-000000000014')->'lines'->0->>'available_quantity', '3', 'la factura conserva tres unidades buenas pendientes');
select is((select sum(quantity)::integer from public.sales_return_lines where return_id = (select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000007') and condition = 'DAMAGED' and inventory_location_id = '81000000-0000-0000-0000-000000000003'), 3, 'las tres unidades dañadas se reciben en cuarentena');
select is((select sum(quantity)::integer from public.sales_return_lines where return_id = (select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000007') and condition = 'DAMAGED' and condition_note = 'Tres unidades quebradas'), 3, 'la nota de daño se conserva en las líneas');
select lives_ok($$select public.sales_confirm_return(
 '82000000-0000-0000-0000-000000000009', '81000000-0000-0000-0000-000000000014',
 'Tres unidades buenas', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000024","product_id":"81000000-0000-0000-0000-000000000005","quantity":3,"condition":"GOOD"}]',
 'CUSTOMER_CREDIT', 'pgTAP', 'pgTAP', 'pgTAP')$$, 'permite una segunda devolución para el resto bueno de la misma línea');
select is(public.sales_preview_return('81000000-0000-0000-0000-000000000014')->'lines'->0->>'available_quantity', '0', 'la línea queda completamente devuelta tras ambos documentos');
select is((select sum(quantity)::integer from public.sales_return_lines rl join public.sales_returns r on r.id = rl.return_id where r.invoice_id = '81000000-0000-0000-0000-000000000014' and rl.invoice_line_id = '81000000-0000-0000-0000-000000000024'), 6, 'la suma acumulada de devoluciones no supera y alcanza la factura');
select throws_ok($$select (public.sales_confirm_return('82000000-0000-0000-0000-000000000010', '81000000-0000-0000-0000-000000000014', 'Unidad adicional', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000024","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"GOOD"}]', 'CUSTOMER_CREDIT', 'pgTAP', 'pgTAP', 'pgTAP')).id$$, 'P0001', 'RETURN_QUANTITY_EXCEEDED', 'rechaza devolver unidades por encima del total facturado');

select lives_ok($$select public.sales_confirm_return('82000000-0000-0000-0000-000000000004', '81000000-0000-0000-0000-000000000012', 'Destino automático', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000022","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000003"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')$$, 'el servidor ignora el destino del cliente y devuelve al origen facturado');
select is((select inventory_location_id from public.sales_return_lines where return_id = (select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000004')), '81000000-0000-0000-0000-000000000002'::uuid, 'producto bueno se enruta a ubicación de salida de la factura');
select ok(not has_table_privilege('authenticated', 'public.sales_returns', 'INSERT'), 'cliente no puede insertar devoluciones directamente');
select ok(not has_table_privilege('authenticated', 'public.inventory_transactions', 'INSERT'), 'cliente no puede insertar movimientos directamente');
select ok(not has_table_privilege('authenticated', 'public.refunds', 'INSERT'), 'cliente no puede insertar reembolsos directamente');
select ok(not has_function_privilege('anon', 'public.sales_preview_return(uuid)', 'EXECUTE'), 'la vista previa de devolución no está expuesta a anon');

reset role;
create function pg_temp.reject_return_inventory() returns trigger
language plpgsql as $$ begin raise exception 'INJECTED_INVENTORY_FAILURE'; end $$;
create trigger reject_return_inventory before insert on public.inventory_transactions
for each row when (new.reason = 'RETURN') execute function pg_temp.reject_return_inventory();
select throws_ok($$select (public.sales_confirm_return('82000000-0000-0000-0000-000000000005', '81000000-0000-0000-0000-000000000013', 'Fallo inventario', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000023","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000002"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')).id$$, 'P0001', 'INJECTED_INVENTORY_FAILURE', 'fallo del modulo inventario aborta el comando completo');
select is((select count(*)::integer from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000005'), 0, 'fallo de inventario revierte la devolución de ventas');
select is((select count(*)::integer from public.refunds where sales_return_id in (select id from public.sales_returns where reason = 'Fallo inventario')), 0, 'fallo de inventario revierte liquidación de pagos');

select * from finish();
rollback;
