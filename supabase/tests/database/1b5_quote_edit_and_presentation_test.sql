begin;
select plan(18);

select has_column('public', 'products', 'units_per_presentation',
  'producto persiste unidades por presentacion');
select has_column('public', 'sales_quote_lines', 'units_per_presentation',
  'linea conserva snapshot del factor');
select has_column('public', 'sales_quote_lines', 'presentation_name',
  'linea conserva nombre de presentacion');
select has_function('public', 'update_quote',
  array['uuid','uuid','text','date','text','uuid','jsonb','text','text','text']::name[],
  'existe RPC atomica de edicion');
select ok(has_function_privilege('anon', 'public.update_quote(uuid,uuid,text,date,text,uuid,jsonb,text,text,text)', 'EXECUTE'),
  'anon usa el contrato RPC existente de la app local');

insert into public.categories(id, name) values
  ('b5500000-0000-4000-8000-000000000001', 'pgTAP quote category');
insert into public.packaging_presentations(id, name) values
  ('b5500000-0000-4000-8000-000000000002', 'Caja pgTAP');
insert into public.products(
  id, sku, name, category_id, unit_price, min_order_quantity,
  minimum_sale_quantity, packaging_presentation_id, units_per_presentation
) values (
  'b5500000-0000-4000-8000-000000000003', 'PGTAP-Q-1', 'Producto de prueba',
  'b5500000-0000-4000-8000-000000000001', 2, 1, 1,
  'b5500000-0000-4000-8000-000000000002', 6
);
insert into public.customers(id, name) values
  ('b5500000-0000-4000-8000-000000000004', 'Cliente pgTAP');

select throws_ok(
  $$update public.products set units_per_presentation = 0 where id = 'b5500000-0000-4000-8000-000000000003'$$,
  '23514', null, 'factor cero rechazado'
);
select is((select units_per_presentation from public.products where id = 'b5500000-0000-4000-8000-000000000003'), 6,
  'producto conserva seis unidades por presentacion');
select throws_ok(
  $$select public.create_product_with_initial_stock('{"units_per_presentation":6.5}'::jsonb, 0, 'pgTAP', 'device', 'device-id')$$,
  'P0001', 'INVALID_PRESENTATION_FACTOR', 'RPC de creacion rechaza factor decimal'
);
select throws_ok(
  $$select public.update_product('b5500000-0000-4000-8000-000000000003', '{"units_per_presentation":0}'::jsonb, 'pgTAP', 'device', 'device-id')$$,
  'P0001', 'INVALID_PRESENTATION_FACTOR', 'RPC rechaza factor cero'
);
select throws_ok(
  $$select public.update_product('b5500000-0000-4000-8000-000000000003', '{"units_per_presentation":-2}'::jsonb, 'pgTAP', 'device', 'device-id')$$,
  'P0001', 'INVALID_PRESENTATION_FACTOR', 'RPC rechaza factor negativo'
);
select throws_ok(
  $$select public.update_product('b5500000-0000-4000-8000-000000000003', '{"units_per_presentation":3.5}'::jsonb, 'pgTAP', 'device', 'device-id')$$,
  'P0001', 'INVALID_PRESENTATION_FACTOR', 'RPC rechaza factor decimal'
);
select throws_ok(
  $$select public.update_product('b5500000-0000-4000-8000-000000000003', '{"units_per_presentation":null}'::jsonb, 'pgTAP', 'device', 'device-id')$$,
  'P0001', 'INVALID_PRESENTATION_FACTOR', 'RPC rechaza factor nulo explicito'
);

create temporary table test_quote as
select (public.create_quote(
  'b5500000-0000-4000-8000-000000000004', 'Cliente pgTAP', 'CRC', 1, null,
  'nota inicial', null,
  '[{"product_id":"b5500000-0000-4000-8000-000000000003","quantity":6,"unit_price":2,"discount_percent":25,"presentation_name":"Caja pgTAP","units_per_presentation":6}]'::jsonb,
  'pgTAP', 'device', 'device-id'
)).id as id;

select is((select total_amount from public.sales_quotes where id = (select id from test_quote)), 9::numeric,
  'create_quote calcula el total con descuento');
select is((select units_per_presentation from public.sales_quote_lines where quote_id = (select id from test_quote)), 6,
  'create_quote conserva snapshot factor seis');

select lives_ok(format(
  $$select public.update_quote(%L, %L, 'Cliente actualizado', null, 'nota editada', null,
  '[{"product_id":"b5500000-0000-4000-8000-000000000003","quantity":12,"unit_price":2,"discount_percent":10,"presentation_name":"Caja pgTAP","units_per_presentation":6}]'::jsonb,
  'pgTAP', 'device', 'device-id')$$,
  (select id from test_quote), 'b5500000-0000-4000-8000-000000000004'
), 'actualiza cabecera y lineas en borrador');
select is((select total_amount from public.sales_quotes where id = (select id from test_quote)), 21.6::numeric,
  'editar recalcula total usando el descuento');
select is((select sum(quantity)::integer from public.sales_quote_lines where quote_id = (select id from test_quote)), 12,
  'edicion reemplaza las lineas completas');

select public.update_quote_status((select id from test_quote), 'SENT', 'pgTAP', 'device', 'device-id');
select throws_ok(
  format($$select public.update_quote(%L, %L, 'Cliente', null, null, null, '[]'::jsonb, 'pgTAP', 'device', 'device-id')$$,
    (select id from test_quote), 'b5500000-0000-4000-8000-000000000004'),
  'P0001', 'QUOTE_NOT_EDITABLE', 'cotizacion enviada no admite cambios'
);

select * from finish();
rollback;
