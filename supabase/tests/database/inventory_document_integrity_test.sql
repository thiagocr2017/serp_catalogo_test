begin;

select plan(17);

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
--   D. atomicidad de la factura de venta contra su documento de inventario.
--
-- Los casos se ejecutan con el rol de la aplicacion (`authenticated`). Las
-- funciones son `SECURITY DEFINER`, asi que prueban la logica real que corre el
-- cliente.

-- Fixtures dentro de la transaccion que se revierte al final.
insert into public.warehouses (id, code, name)
values ('11111111-1111-1111-1111-111111111111', 'B-PG', 'Bodega pgTAP');
insert into public.inventory_locations (id, warehouse_id, code, name)
values ('22222222-2222-2222-2222-222222222222',
        '11111111-1111-1111-1111-111111111111', 'L-PG', 'Ubicacion pgTAP');
insert into public.products (id, sku, name, description, category_id, unit_price,
                             min_order_quantity, packaging_presentation_id,
                             cbm_per_moq, factory_cost, current_stock,
                             reorder_point)
select '33333333-3333-3333-3333-333333333333', 'SKU-PG-1', 'Producto pgTAP 1', '',
       c.id, 100, 1, p.id, 1, 50, 0, 0
  from public.categories c, public.packaging_presentations p limit 1;
insert into public.products (id, sku, name, description, category_id, unit_price,
                             min_order_quantity, packaging_presentation_id,
                             cbm_per_moq, factory_cost, current_stock,
                             reorder_point)
select '44444444-4444-4444-4444-444444444444', 'SKU-PG-2', 'Producto pgTAP 2', '',
       c.id, 100, 1, p.id, 1, 50, 0, 0
  from public.categories c, public.packaging_presentations p limit 1;

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
-- D. Atomicidad factura de venta <-> inventario
-- ---------------------------------------------------------------------------

select throws_ok(
  $$select public.create_sale_invoice_with_dispatch(
      'dddddddd-0000-0000-0000-000000000001', 'Cliente pgTAP', 'USD', 1,
      'factura con linea rota',
      '[{"product_id":"33333333-3333-3333-3333-333333333333","quantity":2},
        {"product_id":"99999999-9999-9999-9999-999999999999","quantity":3}]'::jsonb,
      '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222',
      'pgTAP', 'pgTAP', 'pgTAP')$$,
  null, null,
  'D1 la factura falla si una linea apunta a un producto inexistente'
);

select is(
  (select count(*)::integer from public.sales_invoices
    where invoice_number is not null
      and created_by = 'pgTAP'
      and notes = 'factura con linea rota'),
  0,
  'D2 no queda factura creada'
);
select is(
  (select count(*)::integer from public.inventory_documents
    where notes = 'factura con linea rota'),
  0,
  'D3 no queda documento de inventario huérfano'
);

select * from finish();
rollback;
