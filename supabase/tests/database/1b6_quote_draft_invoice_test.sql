begin;
select plan(15);

select has_column('public', 'sales_invoices', 'source_quote_id',
  'la factura conserva el origen de cotizacion');
select has_column('public', 'sales_quotes', 'converted_invoice_id',
  'la cotizacion conserva el enlace a factura');
select has_function('public', 'create_draft_invoice_from_quote',
  array['uuid', 'uuid', 'text', 'text', 'text']::name[],
  'existe la operacion atomica de continuacion');
select ok(has_function_privilege(
  'authenticated',
  'public.create_draft_invoice_from_quote(uuid,uuid,text,text,text)',
  'EXECUTE'
), 'solo una sesion autenticada puede crear la continuacion');
select ok(not has_function_privilege(
  'anon',
  'public.create_draft_invoice_from_quote(uuid,uuid,text,text,text)',
  'EXECUTE'
), 'la RPC no habilita el rol anon');

insert into public.categories(id, name) values
  ('b6600000-0000-4000-8000-000000000001', 'pgTAP draft invoice category');
insert into public.packaging_presentations(id, name) values
  ('b6600000-0000-4000-8000-000000000002', 'pgTAP draft invoice pack');
insert into public.products(
  id, sku, name, category_id, unit_price, min_order_quantity,
  minimum_sale_quantity, packaging_presentation_id, units_per_presentation
) values (
  'b6600000-0000-4000-8000-000000000003', 'PGTAP-DI-1', 'Producto factura borrador',
  'b6600000-0000-4000-8000-000000000001', 10, 1, 1,
  'b6600000-0000-4000-8000-000000000002', 1
);
insert into public.customers(id, name) values
  ('b6600000-0000-4000-8000-000000000004', 'Cliente factura borrador');

create temporary table _quote as
select (public.create_quote(
  'b6600000-0000-4000-8000-000000000004', 'Cliente factura borrador',
  'CRC', 1, null, 'nota copiada', null,
  '[{"product_id":"b6600000-0000-4000-8000-000000000003","quantity":3,"unit_price":10,"discount_percent":0,"product_sku":"PGTAP-DI-1","product_name":"Producto factura borrador"}]'::jsonb,
  'pgTAP', 'device', 'device-id'
)).id as id;

select public.update_quote_status(
  (select id from _quote), 'ACCEPTED', 'pgTAP', 'device', 'device-id'
);
create temporary table _inventory_before as
select count(*)::integer as count from public.inventory_documents;
create temporary table _invoice_id as
select public.create_draft_invoice_from_quote(
  'b6600000-0000-4000-8000-000000000010',
  (select id from _quote), 'pgTAP', 'device', 'device-id'
) as id;

select is((select status from public.sales_invoices where id = (select id from _invoice_id)),
  'DRAFT', 'la continuacion crea una factura borrador');
select is((select source_quote_id from public.sales_invoices where id = (select id from _invoice_id)),
  (select id from _quote), 'la factura enlaza su cotizacion de origen');
select is((select converted_invoice_id from public.sales_quotes where id = (select id from _quote)),
  (select id from _invoice_id), 'la cotizacion enlaza la factura creada');
select is((select status from public.sales_quotes where id = (select id from _quote)),
  'CONVERTED', 'la cotizacion se marca convertida solo tras crear el destino');
select is((select count(*)::integer from public.sales_invoice_lines where invoice_id = (select id from _invoice_id)),
  1, 'la factura conserva la linea cotizada');
select is((select total_amount from public.sales_invoices where id = (select id from _invoice_id)),
  (select total_amount from public.sales_quotes where id = (select id from _quote)),
  'el total se copia sin recalculo divergente');
select is((select inventory_document_id from public.sales_invoices where id = (select id from _invoice_id)),
  null::uuid, 'la factura borrador no tiene documento de salida');
select is((select count(*)::integer from public.inventory_documents),
  (select count from _inventory_before), 'la continuacion no crea documentos de inventario');
select is(public.create_draft_invoice_from_quote(
  'b6600000-0000-4000-8000-000000000010',
  (select id from _quote), 'pgTAP', 'device', 'device-id'
), (select id from _invoice_id), 'reintentar devuelve la misma factura');
select throws_ok(
  $$select public.create_draft_invoice_from_quote(
    'b6600000-0000-4000-8000-000000000011',
    'b6600000-0000-4000-8000-000000000099', 'pgTAP', 'device', 'device-id')$$,
  'P0001', 'QUOTE_NOT_FOUND', 'no convierte una cotizacion inexistente'
);

select * from finish();
rollback;
