begin;

select plan(52);

-- Integridad del documento de inventario: atomicidad, idempotencia y reversión.
--
-- Estas pruebas son de caracterizacion: describen el comportamiento correcto
-- que ya existe y deben seguir exigiendo. Si alguna falla, algo rompio el libro
-- inmutable.
--
-- Cubren los cuatro puntos que faltaban en Fase 4 de
-- `.specs/refactors/02-tech-debt-plan.md`:
--   A. atomicidad de `create_and_confirm_inventory_document` ante fallo
--      intermedio;
--   B. idempotencia ante reintentos con la misma `command_id`;
--   C. reversión y su limite de una sola reversión directa por movimiento;
--   D. despacho de traslado con salida atomica e idempotencia;
--   E. atomicidad de la factura de venta contra su documento de inventario.
--
-- Los casos se ejecutan con el rol de la aplicacion (`authenticated`). Las
-- funciones son `SECURITY DEFINER`, asi que prueban la logica real que corre el
-- cliente.

-- Fixtures dentro de la transaccion que se revierte al final.
insert into public.warehouses (id, code, name)
values ('11111111-1111-1111-1111-111111111111', 'B-PG', 'Bodega pgTAP');
insert into public.categories (id, name)
values ('99999999-0000-0000-0000-000000000002', 'Categoria descuentos pgTAP');
insert into public.inventory_locations (id, warehouse_id, code, name)
values ('22222222-2222-2222-2222-222222222222',
        '11111111-1111-1111-1111-111111111111', 'L-PG', 'Ubicacion pgTAP');
insert into public.inventory_locations(id, warehouse_id, code, name)
values ('66666666-6666-6666-6666-666666666666',
        '11111111-1111-1111-1111-111111111111', 'L-PG-2', 'Segunda ubicación pgTAP');
insert into public.products (id, sku, name, description, category_id, unit_price,
                             min_order_quantity, packaging_presentation_id,
                             cbm_per_moq, factory_cost, current_stock,
                             reorder_point)
select '33333333-3333-3333-3333-333333333333', 'SKU-PG-1', 'Producto pgTAP 1', '',
       '99999999-0000-0000-0000-000000000002', 100, 1, p.id, 1, 50, 0, 0
  from public.packaging_presentations p limit 1;

insert into public.products (id, sku, name, description, category_id, unit_price,
                             min_order_quantity, packaging_presentation_id,
                             cbm_per_moq, factory_cost, current_stock, promo_price,
                             reorder_point)
select '44444444-4444-4444-4444-444444444444', 'SKU-PG-2', 'Producto pgTAP 2', '',
       '99999999-0000-0000-0000-000000000002', 100, 1, p.id, 1, 50, 0, 80, 0
  from public.packaging_presentations p limit 1;

insert into public.products (id, sku, name, description, category_id, unit_price,
                             min_order_quantity, packaging_presentation_id,
                             cbm_per_moq, factory_cost, current_stock, promo_price,
                             reorder_point)
select '77777777-7777-7777-7777-777777777777', 'SKU-PG-3', 'Producto pgTAP 3', '',
       '99999999-0000-0000-0000-000000000002', 100, 1, p.id, 1, 50, 0, 0, 0
  from public.packaging_presentations p limit 1;

insert into public.customers(id, name, is_active)
values ('55555555-5555-5555-5555-555555555555', 'Cliente pgTAP', true);

insert into public.sales_invoices(id, invoice_number, customer_id, customer_name,
  status, total_amount, currency_code)
values ('88888888-0000-0000-0000-000000000001', 'FAC-DISCOUNT-PG',
  '55555555-5555-5555-5555-555555555555', 'Cliente pgTAP', 'CONFIRMED', 0, 'USD');

select throws_ok(
  $$insert into public.sales_invoice_lines(invoice_id, product_id, quantity,
      unit_price, discount_percent, total_price, product_sku, product_name)
    values ('88888888-0000-0000-0000-000000000001',
      '33333333-3333-3333-3333-333333333333', 1, 100, 100, 0, 'SKU-PG-1', 'Producto pgTAP 1')$$,
  'P0001', 'DISCOUNT_EXCEEDS_APPROVED_PROMOTION',
  'I1 una factura rechaza 100 por ciento sin promocion aprobada'
);
select throws_ok(
  $$insert into public.sales_invoice_lines(invoice_id, product_id, quantity,
      unit_price, discount_percent, total_price, product_sku, product_name)
    values ('88888888-0000-0000-0000-000000000001',
      '44444444-4444-4444-4444-444444444444', 1, 100, 21, 79, 'SKU-PG-2', 'Producto pgTAP 2')$$,
  'P0001', 'DISCOUNT_EXCEEDS_APPROVED_PROMOTION',
  'I2 una factura rechaza descuento superior a la promocion aprobada'
);
select lives_ok(
  $$insert into public.sales_invoice_lines(invoice_id, product_id, quantity,
      unit_price, discount_percent, total_price, product_sku, product_name)
    values ('88888888-0000-0000-0000-000000000001',
      '44444444-4444-4444-4444-444444444444', 1, 100, 20, 80, 'SKU-PG-2', 'Producto pgTAP 2')$$,
  'I3 una factura acepta exactamente el descuento promocional aprobado'
);
select throws_ok(
  $$insert into public.sales_invoice_lines(invoice_id, product_id, quantity,
      unit_price, discount_percent, total_price, product_sku, product_name)
    values ('88888888-0000-0000-0000-000000000001',
      '44444444-4444-4444-4444-444444444444', 1, 200, 20, 160, 'SKU-PG-2', 'Producto pgTAP 2')$$,
  'P0001', 'INVALID_UNIT_PRICE',
  'I4 no se puede evitar el tope manipulando el precio base de factura'
);
select throws_ok(
  $$insert into public.sales_invoice_lines(invoice_id, product_id, quantity,
      unit_price, discount_percent, total_price, product_sku, product_name)
    values ('88888888-0000-0000-0000-000000000001',
      '77777777-7777-7777-7777-777777777777', 1, 100, 100, 0, 'SKU-PG-3', 'Producto pgTAP 3')$$,
  'P0001', 'DISCOUNT_EXCEEDS_APPROVED_PROMOTION',
  'I5 incluso una promoción del 100 por ciento no permite una línea gratuita en factura'
);
select lives_ok(
  $$insert into public.sales_invoice_lines(invoice_id, product_id, quantity,
      unit_price, discount_percent, total_price, product_sku, product_name)
    values ('88888888-0000-0000-0000-000000000001',
      '77777777-7777-7777-7777-777777777777', 1, 100, 99.99, 0.01, 'SKU-PG-3', 'Producto pgTAP 3')$$,
  'I6 una promoción del 100 por ciento se limita a 99.99 por ciento en factura'
);

set local role authenticated;

-- ---------------------------------------------------------------------------
-- A. Atomicidad ante fallo intermedio
-- ---------------------------------------------------------------------------

select throws_ok(
  $$select public.create_and_confirm_inventory_document(
      'aaaaaaaa-0000-0000-0000-000000000001', 'ADJUSTMENT',
      '[{"product_id":"33333333-3333-3333-3333-333333333333","quantity":10},
        {"product_id":"99999999-9999-9999-9999-999999999999","quantity":5}]'::jsonb,
      '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
      null, null, null, 'fallo intermedio', 'pgTAP', 'pgTAP', 'pgTAP')$$,
  null, null,
  'A1 el documento falla si una linea apunta a un producto inexistente'
);

select is(
  (select count(*)::integer from public.inventory_documents
    where command_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  0,
  'A2 no queda documento creado'
);
select is(
  (select count(*)::integer from public.inventory_transactions
    where command_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  0,
  'A3 no queda movimiento creado'
);
select is(
  (select coalesce(sum(quantity), 0)::integer from public.inventory_balances
    where product_id = '33333333-3333-3333-3333-333333333333'),
  0,
  'A4 la linea valida no llego a tocar el saldo'
);

-- ---------------------------------------------------------------------------
-- B. Idempotencia ante reintentos
-- ---------------------------------------------------------------------------

select lives_ok(
  $$select public.create_and_confirm_inventory_document(
      'bbbbbbbb-0000-0000-0000-000000000001', 'ADJUSTMENT',
      '[{"product_id":"33333333-3333-3333-3333-333333333333","quantity":10}]'::jsonb,
      '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
      null, null, null, 'primera vez', 'pgTAP', 'pgTAP', 'pgTAP')$$,
  'B1 el primer envio crea el documento'
);

select lives_ok(
  $$select public.create_and_confirm_inventory_document(
      'bbbbbbbb-0000-0000-0000-000000000001', 'ADJUSTMENT',
      '[{"product_id":"33333333-3333-3333-3333-333333333333","quantity":10}]'::jsonb,
      '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
      null, null, null, 'reintento', 'pgTAP', 'pgTAP', 'pgTAP')$$,
  'B2 el reintento con la misma command_id no revienta'
);

select is(
  (select count(*)::integer from public.inventory_documents
    where command_id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  1,
  'B3 sigue existiendo un unico documento'
);
select is(
  (select count(*)::integer from public.inventory_transactions
    where command_id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  1,
  'B4 el movimiento no se duplico'
);

-- ---------------------------------------------------------------------------
-- C. Reversión y su limite de una sola por movimiento
-- ---------------------------------------------------------------------------

select lives_ok(
  $$select public.record_inventory_transaction(
      'cccccccc-0000-0000-0000-000000000001',
      '44444444-4444-4444-4444-444444444444',
      '22222222-2222-2222-2222-222222222222',
      7, 'ADJUSTMENT', 'movimiento original', 'pgTAP', 'pgTAP', 'pgTAP')$$,
  'C1 se registra el movimiento original'
);

select lives_ok(
  $$select public.reverse_inventory_transaction(
      'cccccccc-0000-0000-0000-000000000002',
      (select id from public.inventory_transactions
        where command_id = 'cccccccc-0000-0000-0000-000000000001'),
      'reversion', 'pgTAP', 'pgTAP', 'pgTAP')$$,
  'C2 la reversión se registra'
);

select is(
  (select quantity from public.inventory_transactions
    where command_id = 'cccccccc-0000-0000-0000-000000000002'),
  -7,
  'C3 la reversión usa la cantidad opuesta'
);
select is(
  (select count(*)::integer from public.inventory_transactions t
    where t.reversal_of_transaction_id =
          (select id from public.inventory_transactions
            where command_id = 'cccccccc-0000-0000-0000-000000000001')),
  1,
  'C4 la reversión enlaza al movimiento original'
);

select throws_ok(
  $$select public.reverse_inventory_transaction(
      'cccccccc-0000-0000-0000-000000000003',
      (select id from public.inventory_transactions
        where command_id = 'cccccccc-0000-0000-0000-000000000001'),
      'segunda reversion', 'pgTAP', 'pgTAP', 'pgTAP')$$,
  null, null,
  'C5 una segunda reversión del mismo movimiento falla'
);
select is(
  (select count(*)::integer from public.inventory_transactions t
    where t.reversal_of_transaction_id =
          (select id from public.inventory_transactions
            where command_id = 'cccccccc-0000-0000-0000-000000000001')),
  1,
  'C6 sigue existiendo una sola reversión directa por movimiento'
);

-- ---------------------------------------------------------------------------
-- D. Un despacho de traslado confirma el borrador con salida atomica e idempotente
-- ---------------------------------------------------------------------------

select public.record_inventory_transaction(
  'cccccccc-0000-0000-0000-000000000004',
  '44444444-4444-4444-4444-444444444444',
  '22222222-2222-2222-2222-222222222222',
  5, 'ADJUSTMENT', 'stock para traslado borrador', 'pgTAP', 'pgTAP', 'pgTAP');

select lives_ok(
  $$select public.create_and_confirm_inventory_document(
      'cccccccc-0000-0000-0000-000000000005', 'TRANSFER',
      '[{"product_id":"44444444-4444-4444-4444-444444444444","quantity":2}]'::jsonb,
      '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
      '11111111-1111-1111-1111-111111111111', '66666666-6666-6666-6666-666666666666',
      null, 'traslado borrador', 'pgTAP', 'pgTAP', 'pgTAP', true)$$,
  'D1 se crea un borrador de traslado'
);
select is(
  (select status::text from public.inventory_documents
    where command_id = 'cccccccc-0000-0000-0000-000000000005'),
  'BORRADOR',
  'D2 el traslado se conserva como borrador'
);
select is(
  (select count(*)::integer from public.inventory_transactions t
    join public.inventory_documents d on d.id = t.document_id
    where d.command_id = 'cccccccc-0000-0000-0000-000000000005'),
  0,
  'D3 guardar borrador aun no mueve stock'
);
select lives_ok(
  $$select public.dispatch_transfer(
      (select id from public.inventory_documents
        where command_id = 'cccccccc-0000-0000-0000-000000000005'),
      'pgTAP', 'pgTAP', 'pgTAP')$$,
  'D4 despachar confirma el traslado y registra salida'
);
select is(
  (select status::text from public.inventory_documents
    where command_id = 'cccccccc-0000-0000-0000-000000000005'),
  'DESPACHADA',
  'D5 el traslado queda despachado'
);
select is(
  (select count(*)::integer from public.inventory_transactions t
    join public.inventory_documents d on d.id = t.document_id
    where d.command_id = 'cccccccc-0000-0000-0000-000000000005'
      and t.reason = 'TRANSFER_OUT' and t.quantity = -2),
  1,
  'D6 se crea una unica salida por la cantidad del traslado'
);
select lives_ok(
  $$select public.dispatch_transfer(
      (select id from public.inventory_documents
        where command_id = 'cccccccc-0000-0000-0000-000000000005'),
      'pgTAP', 'pgTAP', 'pgTAP')$$,
  'D7 reintentar despacho ya completado devuelve exito'
);
select is(
  (select count(*)::integer from public.inventory_transactions t
    join public.inventory_documents d on d.id = t.document_id
    where d.command_id = 'cccccccc-0000-0000-0000-000000000005'
      and t.reason = 'TRANSFER_OUT'),
  1,
  'D8 el reintento no duplica la salida'
);
select is(
  (select quantity from public.inventory_balances
    where product_id = '44444444-4444-4444-4444-444444444444'
      and location_id = '22222222-2222-2222-2222-222222222222'),
  3,
  'D9 el saldo origen cambia en la misma confirmacion del traslado'
);
select lives_ok(
  $$select public.mark_transfer_in_transit(
      (select id from public.inventory_documents
        where command_id = 'cccccccc-0000-0000-0000-000000000005'),
      'pgTAP', 'pgTAP', 'pgTAP')$$,
  'D10 un traslado despachado puede marcarse en transito'
);
select is(
  (select status::text from public.inventory_documents
    where command_id = 'cccccccc-0000-0000-0000-000000000005'),
  'EN_TRANSITO',
  'D11 el traslado refleja EN_TRANSITO'
);
select lives_ok(
  $$select public.mark_transfer_in_transit(
      (select id from public.inventory_documents
        where command_id = 'cccccccc-0000-0000-0000-000000000005'),
      'pgTAP', 'pgTAP', 'pgTAP')$$,
  'D12 reintentar el cambio a en transito es seguro'
);
select is(
  (select status::text from public.inventory_documents
    where command_id = 'cccccccc-0000-0000-0000-000000000005'),
  'EN_TRANSITO',
  'D13 el reintento mantiene EN_TRANSITO'
);
select lives_ok(
  $$select public.receive_transfer(
      (select id from public.inventory_documents
        where command_id = 'cccccccc-0000-0000-0000-000000000005'),
      'pgTAP', 'pgTAP', 'pgTAP')$$,
  'D14 se recibe el traslado en destino'
);
select is(
  (select status::text from public.inventory_documents
    where command_id = 'cccccccc-0000-0000-0000-000000000005'),
  'RECIBIDA',
  'D15 el traslado queda RECIBIDA'
);
select is(
  (select count(*)::integer from public.inventory_transactions t
    join public.inventory_documents d on d.id = t.document_id
    where d.command_id = 'cccccccc-0000-0000-0000-000000000005'
      and t.reason = 'TRANSFER_IN' and t.quantity = 2),
  1,
  'D16 la recepcion crea una entrada positiva unica'
);
select is(
  (select quantity from public.inventory_balances
    where product_id = '44444444-4444-4444-4444-444444444444'
      and location_id = '66666666-6666-6666-6666-666666666666'),
  2,
  'D17 el saldo destino se actualiza al recibir'
);
select lives_ok(
  $$select public.receive_transfer(
      (select id from public.inventory_documents
        where command_id = 'cccccccc-0000-0000-0000-000000000005'),
      'pgTAP', 'pgTAP', 'pgTAP')$$,
  'D18 reintentar la recepcion completada es seguro'
);
select is(
  (select count(*)::integer from public.inventory_transactions t
    join public.inventory_documents d on d.id = t.document_id
    where d.command_id = 'cccccccc-0000-0000-0000-000000000005'
      and t.reason = 'TRANSFER_IN'),
  1,
  'D19 el reintento no duplica la entrada'
);

-- ---------------------------------------------------------------------------
-- E. Atomicidad factura de venta <-> inventario
-- ---------------------------------------------------------------------------

select throws_ok(
  $$select public.create_sale_invoice_with_dispatch(
      'dddddddd-0000-0000-0000-000000000001',
      '55555555-5555-5555-5555-555555555555', 'Cliente pgTAP', 'USD', 1,
      'factura con linea rota',
      '[{"product_id":"33333333-3333-3333-3333-333333333333","quantity":2,"unit_price":100},
        {"product_id":"99999999-9999-9999-9999-999999999999","quantity":3,"unit_price":100}]'::jsonb,
      '11111111-1111-1111-1111-111111111111',
      'pgTAP', 'pgTAP', 'pgTAP')$$,
  null, null,
  'E1 la factura falla si una linea apunta a un producto inexistente'
);

select is(
  (select count(*)::integer from public.sales_invoices
    where invoice_number is not null
      and created_by = 'pgTAP'
      and notes = 'factura con linea rota'),
  0,
  'E2 no queda factura creada'
);
select is(
  (select count(*)::integer from public.inventory_documents
    where notes = 'factura con linea rota'),
  0,
  'E3 no queda documento de inventario huerfano'
);

-- La factura asigna stock desde todas las ubicaciones activas de la bodega.
select public.record_inventory_transaction(
  'eeeeeeee-0000-0000-0000-000000000001',
  '33333333-3333-3333-3333-333333333333',
  '22222222-2222-2222-2222-222222222222',
  2, 'ADJUSTMENT', 'stock inicial en ubicacion 1', 'pgTAP', 'pgTAP', 'pgTAP');
select public.record_inventory_transaction(
  'eeeeeeee-0000-0000-0000-000000000002',
  '33333333-3333-3333-3333-333333333333',
  '66666666-6666-6666-6666-666666666666',
  3, 'ADJUSTMENT', 'stock inicial en ubicacion 2', 'pgTAP', 'pgTAP', 'pgTAP');

select lives_ok(
  $$select public.create_sale_invoice_with_dispatch(
      'eeeeeeee-0000-0000-0000-000000000003',
      '55555555-5555-5555-5555-555555555555', 'Cliente pgTAP', 'USD', 1,
      'factura multi ubicacion',
      '[{"product_id":"33333333-3333-3333-3333-333333333333","quantity":4,"unit_price":100}]'::jsonb,
      '11111111-1111-1111-1111-111111111111', 'pgTAP', 'pgTAP', 'pgTAP')$$,
  'E4 la factura consume existencia combinada de la bodega'
);
select is(
  (select customer_id from public.sales_invoices where notes = 'factura multi ubicacion'),
  '55555555-5555-5555-5555-555555555555'::uuid,
  'E5 la factura conserva el cliente relacionado'
);
select is(
  (select d.origin_location_id from public.sales_invoices i
    join public.inventory_documents d on d.id = i.inventory_document_id
   where i.notes = 'factura multi ubicacion'),
  null::uuid,
  'E6 el documento de salida conserva bodega sin fijar una ubicacion unica'
);
select is(
  (select count(*)::integer from public.inventory_transactions t
    join public.sales_invoices i on i.inventory_document_id = t.document_id
   where i.notes = 'factura multi ubicacion' and t.reason = 'SALE'),
  2,
  'E7 los movimientos reflejan las dos ubicaciones reales'
);
select is(
  (select quantity from public.inventory_balances
    where product_id = '33333333-3333-3333-3333-333333333333'
      and location_id = '22222222-2222-2222-2222-222222222222'),
  0,
  'E8 se consume primero el stock de la ubicacion predeterminada'
);
select is(
  (select quantity from public.inventory_balances
    where product_id = '33333333-3333-3333-3333-333333333333'
      and location_id = '66666666-6666-6666-6666-666666666666'),
  1,
  'E9 se consume el saldo restante de la segunda ubicacion'
);
select throws_ok(
  $$select public.create_sale_invoice_with_dispatch(
      'eeeeeeee-0000-0000-0000-000000000004',
      '55555555-5555-5555-5555-555555555555', 'Cliente pgTAP', 'USD', 1,
      'factura stock insuficiente',
      '[{"product_id":"33333333-3333-3333-3333-333333333333","quantity":2,"unit_price":100}]'::jsonb,
      '11111111-1111-1111-1111-111111111111', 'pgTAP', 'pgTAP', 'pgTAP')$$,
  null, null,
  'E10 no crea una factura cuando la suma de ubicaciones es insuficiente'
);
select is(
  (select count(*)::integer from public.sales_invoices where notes = 'factura stock insuficiente'),
  0,
  'E11 fallo de disponibilidad no deja factura parcial'
);
select throws_ok(
  $$select public.create_sale_invoice_with_dispatch(
      'eeeeeeee-0000-0000-0000-000000000005',
      '55555555-5555-5555-5555-555555555555', 'Cliente pgTAP', 'USD', 1,
      'factura producto repetido insuficiente',
      '[{"product_id":"33333333-3333-3333-3333-333333333333","quantity":1,"unit_price":100},
        {"product_id":"33333333-3333-3333-3333-333333333333","quantity":1,"unit_price":100}]'::jsonb,
      '11111111-1111-1111-1111-111111111111', 'pgTAP', 'pgTAP', 'pgTAP')$$,
  null, null,
  'E12 suma las lineas repetidas del producto para validar existencias'
);
select is(
  (select count(*)::integer from public.sales_invoices
    where notes = 'factura producto repetido insuficiente'),
  0,
  'E13 la suma insuficiente de lineas repetidas tampoco deja factura parcial'
);

select * from finish();
rollback;
