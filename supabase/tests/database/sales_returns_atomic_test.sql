begin;

select plan(27);

insert into public.warehouses(id, code, name)
values ('81000000-0000-0000-0000-000000000001', 'RET-PG', 'Bodega devoluciones');
insert into public.inventory_locations(id, warehouse_id, code, name, stock_role)
values
 ('81000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000001', 'SELL', 'Vendible', 'SELLABLE'),
 ('81000000-0000-0000-0000-000000000003', '81000000-0000-0000-0000-000000000001', 'QUAR', 'Cuarentena', 'QUARANTINE');
insert into public.categories(id, name)
values ('81000000-0000-0000-0000-000000000004', 'Categoria devoluciones');
insert into public.packaging_presentations(id, name, sort_order)
values ('81000000-0000-0000-0000-000000000007', 'Unidad pgTAP', 900)
on conflict do nothing;
insert into public.products(id, sku, name, description, category_id, unit_price,
  min_order_quantity, packaging_presentation_id, cbm_per_moq, factory_cost,
  current_stock, reorder_point)
select '81000000-0000-0000-0000-000000000005', 'RET-PG-1', 'Producto devolución', '',
  '81000000-0000-0000-0000-000000000004', 50, 1, '81000000-0000-0000-0000-000000000007', 0, 0, 0, 0;
insert into public.customers(id, name, is_active)
values ('81000000-0000-0000-0000-000000000006', 'Cliente devolución', true);

insert into public.sales_invoices(id, invoice_number, customer_id, customer_name,
  status, total_amount, currency_code)
values
 ('81000000-0000-0000-0000-000000000010', 'FAC-RET-PG-1', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 'CONFIRMED', 100, 'USD'),
 ('81000000-0000-0000-0000-000000000011', 'FAC-RET-PG-2', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 'CONFIRMED', 100, 'USD'),
 ('81000000-0000-0000-0000-000000000012', 'FAC-RET-PG-3', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 'CONFIRMED', 100, 'USD'),
 ('81000000-0000-0000-0000-000000000013', 'FAC-RET-PG-4', '81000000-0000-0000-0000-000000000006', 'Cliente devolución', 'CONFIRMED', 100, 'USD');
insert into public.sales_invoice_lines(id, invoice_id, product_id, quantity,
  unit_price, discount_percent, total_price, product_sku, product_name)
values
 ('81000000-0000-0000-0000-000000000020', '81000000-0000-0000-0000-000000000010', '81000000-0000-0000-0000-000000000005', 2, 50, 10, 90, 'RET-PG-1', 'Producto devolución'),
 ('81000000-0000-0000-0000-000000000021', '81000000-0000-0000-0000-000000000011', '81000000-0000-0000-0000-000000000005', 1, 50, 0, 50, 'RET-PG-1', 'Producto devolución'),
 ('81000000-0000-0000-0000-000000000022', '81000000-0000-0000-0000-000000000012', '81000000-0000-0000-0000-000000000005', 1, 50, 0, 50, 'RET-PG-1', 'Producto devolución'),
 ('81000000-0000-0000-0000-000000000023', '81000000-0000-0000-0000-000000000013', '81000000-0000-0000-0000-000000000005', 1, 50, 0, 50, 'RET-PG-1', 'Producto devolución');
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
select throws_ok($$select (public.sales_confirm_return('82000000-0000-0000-0000-000000000006', '81000000-0000-0000-0000-000000000010', 'Devolución parcial', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000020","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000002"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')).id$$, 'P0001', 'RETURN_QUANTITY_EXCEEDED', 'rechaza devolver parcialmente una línea');
select is((select count(*)::integer from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000006'), 0, 'el intento parcial no crea devolución');

select lives_ok($$select public.sales_confirm_return(
 '82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000010',
 'Empaque abierto', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000020","product_id":"81000000-0000-0000-0000-000000000005","quantity":2,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000002"}]',
 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')$$, 'confirmación crea devolución y efectos en una transacción');
select is((select total_amount from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001'), 90::numeric, 'precio neto original conserva descuento facturado');
select is((select debt_reduction_amount from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001'), 20::numeric, 'primero reduce saldo impago');
select is((select financial_resolution_amount from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001'), 70::numeric, 'solo liquida excedente sobre saldo');
select is((select sum(quantity)::integer from public.inventory_balances where product_id = '81000000-0000-0000-0000-000000000005' and location_id = '81000000-0000-0000-0000-000000000002'), 2, 'producto bueno se recibe en ubicación vendible');
select is((select current_stock from public.products where id = '81000000-0000-0000-0000-000000000005'), 2, 'stock público incluye solo ubicación vendible');
select is((select count(*)::integer from public.refunds where sales_return_id = (select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001')), 2, 'reembolso se distribuye entre pagos elegibles');
select is((select sum(amount) from public.refunds where sales_return_id = (select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001')), 70::numeric, 'suma reembolsada iguala el excedente');

select is((select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000001'),
  (select (public.sales_confirm_return('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000010', 'Empaque abierto', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000020","product_id":"81000000-0000-0000-0000-000000000005","quantity":2,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000002"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')).id), 'reintento devuelve el mismo documento');
select throws_ok($$select (public.sales_confirm_return('82000000-0000-0000-0000-000000000001', '81000000-0000-0000-0000-000000000010', 'Otro motivo', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000020","product_id":"81000000-0000-0000-0000-000000000005","quantity":2,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000002"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')).id$$, 'P0001', 'COMMAND_ID_CONFLICT', 'mismo comando con payload distinto falla');
select throws_ok($$select (public.sales_confirm_return('82000000-0000-0000-0000-000000000002', '81000000-0000-0000-0000-000000000010', 'Duplicado', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000020","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000002"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')).id$$, 'P0001', 'RETURN_QUANTITY_EXCEEDED', 'línea confirmada no se devuelve por segunda vez');

select lives_ok($$select public.sales_confirm_return(
 '82000000-0000-0000-0000-000000000003', '81000000-0000-0000-0000-000000000011',
 'Producto dañado', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000021","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"DAMAGED","location_id":"81000000-0000-0000-0000-000000000003"}]',
 'CUSTOMER_CREDIT', 'pgTAP', 'pgTAP', 'pgTAP')$$, 'dañado ingresa a cuarentena y excedente se registra como crédito');
select is((select sum(quantity)::integer from public.inventory_balances where product_id = '81000000-0000-0000-0000-000000000005' and location_id = '81000000-0000-0000-0000-000000000003'), 1, 'cuarentena conserva cantidad física');
select is((select current_stock from public.products where id = '81000000-0000-0000-0000-000000000005'), 2, 'cuarentena no aumenta stock vendible');
select is((select amount from public.customer_credit_entries where sales_return_id = (select id from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000003')), 50::numeric, 'crédito se limita al excedente pagado');

select throws_ok($$select (public.sales_confirm_return('82000000-0000-0000-0000-000000000004', '81000000-0000-0000-0000-000000000012', 'Ubicación incorrecta', '[{"invoice_line_id":"81000000-0000-0000-0000-000000000022","product_id":"81000000-0000-0000-0000-000000000005","quantity":1,"condition":"GOOD","location_id":"81000000-0000-0000-0000-000000000003"}]', 'REFUND', 'pgTAP', 'pgTAP', 'pgTAP')).id$$, 'P0001', 'LOCATION_ROLE_MISMATCH', 'no permite producto bueno en cuarentena');
select is((select count(*)::integer from public.sales_returns where command_id = '82000000-0000-0000-0000-000000000004'), 0, 'error de destino revierte la devolución');
select ok(not has_table_privilege('authenticated', 'public.sales_returns', 'INSERT'), 'cliente no puede insertar devoluciones directamente');
select ok(not has_table_privilege('authenticated', 'public.inventory_transactions', 'INSERT'), 'cliente no puede insertar movimientos directamente');
select ok(not has_table_privilege('authenticated', 'public.refunds', 'INSERT'), 'cliente no puede insertar reembolsos directamente');

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
