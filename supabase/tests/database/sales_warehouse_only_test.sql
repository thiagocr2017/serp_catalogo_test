begin;
select plan(10);

select has_function(
  'public', 'allocate_sales_dispatch_from_warehouse',
  '{uuid,uuid,jsonb,text,text,text}'::text[],
  'existe el asignador atomico por bodega'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.create_order_with_reservation(uuid,text,character,numeric,text,uuid,uuid,jsonb,uuid,uuid,text,text,text)',
    'EXECUTE'
  ),
  'anon no puede crear pedidos'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.create_order_with_reservation(uuid,text,character,numeric,text,uuid,uuid,jsonb,uuid,uuid,text,text,text)',
    'EXECUTE'
  ),
  'una sesion Auth puede crear pedidos'
);

insert into public.warehouses(id, code, name)
values ('83000000-0000-0000-0000-000000000001', 'WH-ONLY-PG', 'Bodega prueba');
insert into public.inventory_locations(id, warehouse_id, code, name, is_default, stock_role)
values
 ('83000000-0000-0000-0000-000000000002', '83000000-0000-0000-0000-000000000001', 'A', 'Ubicacion A', true, 'SELLABLE'),
 ('83000000-0000-0000-0000-000000000003', '83000000-0000-0000-0000-000000000001', 'B', 'Ubicacion B', false, 'SELLABLE');
insert into public.categories(id, name)
values ('83000000-0000-0000-0000-000000000004', 'Categoria prueba bodega');
insert into public.packaging_presentations(id, name, sort_order)
values ('83000000-0000-0000-0000-000000000005', 'Unidad prueba bodega', 990);
insert into public.products(id, sku, name, category_id, unit_price,
  min_order_quantity, packaging_presentation_id, current_stock)
values ('83000000-0000-0000-0000-000000000006', 'WH-ONLY-PG-1', 'Producto bodega',
  '83000000-0000-0000-0000-000000000004', 10, 1,
  '83000000-0000-0000-0000-000000000005', 0);
insert into public.customers(id, name, is_active)
values ('83000000-0000-0000-0000-000000000007', 'Cliente bodega', true);

select public.record_inventory_transaction(
  '83000000-0000-0000-0000-000000000008',
  '83000000-0000-0000-0000-000000000006',
  '83000000-0000-0000-0000-000000000002',
  2, 'ADJUSTMENT', 'saldo inicial', 'pgTAP', 'pgTAP', 'pgTAP'
);
select public.record_inventory_transaction(
  '83000000-0000-0000-0000-000000000009',
  '83000000-0000-0000-0000-000000000006',
  '83000000-0000-0000-0000-000000000003',
  2, 'ADJUSTMENT', 'saldo inicial', 'pgTAP', 'pgTAP', 'pgTAP'
);

create temporary table created_order as
select (public.create_order_with_reservation(
  '83000000-0000-0000-0000-000000000007', 'Cliente bodega', 'CRC', 1,
  null, null, null,
  '[{"product_id":"83000000-0000-0000-0000-000000000006","quantity":3,"unit_price":10,"product_sku":"WH-ONLY-PG-1","product_name":"Producto bodega"}]'::jsonb,
  '83000000-0000-0000-0000-000000000001', null,
  'pgTAP', 'pgTAP', 'pgTAP'
)).id as id;

select is(
  (select count(*)::integer from public.inventory_transactions t
   join public.sales_orders o on o.inventory_document_id = t.document_id
   where o.id = (select id from created_order) and t.reason = 'SALE'),
  2,
  'pedido distribuye la salida en mas de una ubicacion de la bodega'
);
select is(
  (select sum(t.quantity)::integer from public.inventory_transactions t
   join public.sales_orders o on o.inventory_document_id = t.document_id
   where o.id = (select id from created_order) and t.reason = 'SALE'),
  -3,
  'pedido descuenta exactamente la cantidad solicitada'
);
select is(
  (select d.origin_location_id from public.inventory_documents d
   join public.sales_orders o on o.inventory_document_id = d.id
   where o.id = (select id from created_order)),
  null::uuid,
  'documento de pedido no finge una ubicacion unica de origen'
);

create temporary table created_consignment as
select (public.create_consignment(
  '83000000-0000-0000-0000-000000000007', 'Cliente bodega', 'CRC',
  null, null,
  '[{"product_id":"83000000-0000-0000-0000-000000000006","quantity":1,"unit_price":10,"product_sku":"WH-ONLY-PG-1","product_name":"Producto bodega"}]'::jsonb,
  '83000000-0000-0000-0000-000000000001', null,
  'pgTAP', 'pgTAP', 'pgTAP'
)).id as id;
select is(
  (select sum(t.quantity)::integer from public.inventory_transactions t
   join public.sales_consignments c on c.inventory_document_id = t.document_id
   where c.id = (select id from created_consignment) and t.reason = 'SALE'),
  -1,
  'consignacion descuenta stock desde la bodega sin ubicacion elegida'
);
select ok(
  (select count(distinct t.location_id) = 2
     from public.inventory_transactions t
     join public.sales_orders o on o.inventory_document_id = t.document_id
    where o.id = (select id from created_order)),
  'los movimientos conservan la ubicacion fisica real'
);

select throws_ok(
  $$select public.create_consignment(
    '83000000-0000-0000-0000-000000000007', 'Cliente bodega', 'CRC',
    null, null,
    '[{"product_id":"83000000-0000-0000-0000-000000000006","quantity":5,"unit_price":10}]'::jsonb,
    '83000000-0000-0000-0000-000000000001', null,
    'pgTAP', 'pgTAP', 'pgTAP')$$,
  'P0001', 'INSUFFICIENT_STOCK',
  'consignacion rechaza cantidad mayor al stock restante de toda la bodega'
);
select is(
  (select count(*)::integer from public.sales_consignments
   where customer_id = '83000000-0000-0000-0000-000000000007'),
  1,
  'error de stock revierte completamente la consignacion'
);

select * from finish();
rollback;
