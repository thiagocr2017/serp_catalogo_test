-- Dataset de demostracion para entorno local TEST.
-- Aplicar manualmente con:
-- docker exec -i supabase_db_serp psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/seed_demo.sql
-- No elimina datos y es idempotente. Todos los registros creados llevan
-- created_by = 'demo-seed'; solo insertar documentos la primera vez.

begin;

do $$
begin
  if coalesce((select app_mode from public.app_settings where id = true), 'TEST') <> 'TEST' then
    raise exception 'La carga demo solo se permite cuando app_mode = TEST';
  end if;
end;
$$;

insert into public.packaging_presentations (name, units_per_presentation, sort_order, created_by, created_device_name, created_device_identifier)
values
  ('Unidad', 1, 0, 'demo-seed', 'Demo local', 'demo-seed'),
  ('Caja 6 unidades', 6, 1, 'demo-seed', 'Demo local', 'demo-seed'),
  ('Caja 12 unidades', 12, 2, 'demo-seed', 'Demo local', 'demo-seed'),
  ('Paquete 3 unidades', 3, 3, 'demo-seed', 'Demo local', 'demo-seed'),
  ('Set 4 unidades', 4, 4, 'demo-seed', 'Demo local', 'demo-seed')
on conflict (lower(trim(name))) do update
set units_per_presentation = excluded.units_per_presentation,
    sort_order = excluded.sort_order;

insert into public.categories (id, name, created_by, created_device_name, created_device_identifier)
values
  ('10000000-0000-0000-0000-000000000001', 'Hogar', 'demo-seed', 'Demo local', 'demo-seed'),
  ('10000000-0000-0000-0000-000000000002', 'Cocina', 'demo-seed', 'Demo local', 'demo-seed'),
  ('10000000-0000-0000-0000-000000000003', 'Organización', 'demo-seed', 'Demo local', 'demo-seed'),
  ('10000000-0000-0000-0000-000000000004', 'Oficina', 'demo-seed', 'Demo local', 'demo-seed'),
  ('10000000-0000-0000-0000-000000000005', 'Accesorios', 'demo-seed', 'Demo local', 'demo-seed')
on conflict (id) do update set name = excluded.name;

insert into public.products (
  id, sku, name, description, category_id, currency_code, unit_price,
  package_price, min_order_quantity, minimum_sale_quantity,
  packaging_presentation_id, cbm_per_moq, factory_cost, reorder_point,
  created_by, created_device_name, created_device_identifier
)
select
  ('20000000-0000-0000-0000-' || lpad((1000 + n)::text, 12, '0'))::uuid,
  'DEMO-' || lpad(n::text, 3, '0'),
  (array[
    'Organizador modular', 'Canasta apilable', 'Caja multiuso', 'Repisa compacta',
    'Contenedor con tapa', 'Cesto ventilado', 'Estante plegable', 'Bandeja organizadora',
    'Caja bajo cama', 'Perchero de pared', 'Separador ajustable', 'Carrito auxiliar',
    'Organizador de cajón', 'Cesto de ropa', 'Caja transparente', 'Soporte multiuso',
    'Estante esquinero', 'Organizador colgante', 'Canasto tejido', 'Mueble auxiliar'
  ])[((n - 1) % 20) + 1] || ' ' || lpad(((n - 1) / 20 + 1)::text, 2, '0'),
  'Artículo de demostración para ' || c.name || ', con datos comerciales de prueba.',
  c.id,
  'USD',
  round((2.35 + ((n * 137) % 6200) / 100.0)::numeric, 2),
  round(((2.35 + ((n * 137) % 6200) / 100.0) * (1 + ((n - 1) % 5)))::numeric, 2),
  1 + ((n - 1) % 6),
  1,
  pp.id,
  round((0.008 + ((n * 13) % 80) / 1000.0)::numeric, 6),
  round(((2.35 + ((n * 137) % 6200) / 100.0) * 0.48)::numeric, 2),
  4 + ((n * 7) % 15),
  'demo-seed', 'Demo local', 'demo-seed'
from generate_series(1, 100) as g(n)
join public.categories c
  on c.id = ('10000000-0000-0000-0000-' || lpad((1 + ((n - 1) / 20))::text, 12, '0'))::uuid
join public.packaging_presentations pp
  on lower(pp.name) = lower(case when n % 5 = 0 then 'Caja 6 unidades'
                                 when n % 5 = 1 then 'Unidad'
                                 when n % 5 = 2 then 'Caja 12 unidades'
                                 when n % 5 = 3 then 'Paquete 3 unidades'
                                 else 'Set 4 unidades' end)
on conflict (id) do nothing;

insert into public.customers (
  id, name, display_name, phone, email, address, tax_id, country_code,
  province, city, gira, customer_type, credit_days, credit_limit,
  document_preference, requires_e_invoice, identification_type_id, economic_activity,
  shipping_payment_policy, created_by, created_device_name, created_device_identifier
)
select
  ('40000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
  (array['Comercial Central', 'Distribuidora Horizonte', 'Bazar La Esquina',
         'Suministros del Valle', 'Punto Hogar', 'Almacén Río Claro',
         'Grupo Mercantil Norte', 'Tienda Buen Precio', 'Casa y Oficina',
         'Abastecedora Moderna', 'Comercial La Plaza', 'Servicios Integrales',
         'Distribuciones del Este', 'Bazar San Miguel', 'Importadora Roble',
         'Mercado Familiar', 'Suministros San José', 'Comercial del Pacífico',
         'Tienda El Parque', 'Abastecedora Central'])[((n - 1) % 20) + 1]
    || ' ' || lpad(n::text, 2, '0'),
  'Cliente Demo ' || lpad(n::text, 2, '0'),
  '+506 8000-' || lpad((1000 + n)::text, 4, '0'),
  'cliente' || lpad(n::text, 2, '0') || '@example.test',
  '100 m al norte del parque central, local ' || lpad(n::text, 2, '0'),
  'DEMO-ID-' || lpad(n::text, 6, '0'), 'CR',
  (array['San José', 'Alajuela', 'Cartago', 'Heredia', 'Puntarenas'])[((n - 1) % 5) + 1],
  (array['San José', 'Alajuela', 'Cartago', 'Heredia', 'Puntarenas'])[((n - 1) % 5) + 1],
  'Ruta ' || lpad(((n - 1) % 8 + 1)::text, 2, '0'),
  case when n % 4 = 0 then 'CREDIT' else 'CASH' end,
  case when n % 4 = 0 then 30 else null end,
  case when n % 4 = 0 then 5000 else 0 end,
  case when n % 3 = 0 then 'TICKET' else 'E_INVOICE' end,
  n % 3 <> 0,
  case when n % 3 <> 0 then (select id from public.identification_types where code = 'PHYSICAL_ID') else null end,
  case when n % 3 <> 0 then 'Comercio al por menor' else null end,
  (array['INCLUDED', 'PREPAID', 'CASH_ON_DELIVERY'])[(n - 1) % 3 + 1],
  'demo-seed', 'Demo local', 'demo-seed'
from generate_series(1, 24) as g(n)
where (n % 3 = 0 or exists (select 1 from public.identification_types where code = 'PHYSICAL_ID'))
on conflict (id) do nothing;

insert into public.customer_contacts (id, customer_id, name, phone, role, created_by, created_device_name, created_device_identifier)
select
  ('41000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
  ('40000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
  (array['Andrea Mora', 'Carlos Rojas', 'Daniela Vega', 'Esteban Solís', 'Fernanda León'])[((n - 1) % 5) + 1],
  '+506 8100-' || lpad((2000 + n)::text, 4, '0'),
  (array['Compras', 'Administración', 'Propietario'])[((n - 1) % 3) + 1],
  'demo-seed', 'Demo local', 'demo-seed'
from generate_series(1, 24) as g(n)
on conflict (id) do nothing;

insert into public.customer_category_assignments (customer_id, category_id)
select
  ('40000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
  cc.id
from generate_series(1, 24) as g(n)
join public.customer_categories cc
  on lower(cc.name) = lower(case n % 5
    when 0 then 'Mayorista'
    when 1 then 'Detallista'
    when 2 then 'Distribuidor'
    when 3 then 'Corporativo'
    else 'Institucional' end)
on conflict do nothing;

insert into public.sales_agents (id, name, phone, created_by, created_device_name, created_device_identifier)
values
  ('50000000-0000-0000-0000-000000000001', 'Agente Demo Ana', '+506 8200-1001', 'demo-seed', 'Demo local', 'demo-seed'),
  ('50000000-0000-0000-0000-000000000002', 'Agente Demo Luis', '+506 8200-1002', 'demo-seed', 'Demo local', 'demo-seed'),
  ('50000000-0000-0000-0000-000000000003', 'Agente Demo Sofía', '+506 8200-1003', 'demo-seed', 'Demo local', 'demo-seed')
on conflict (id) do nothing;

do $$
declare
  v_warehouse public.warehouses%rowtype;
begin
  perform public.create_carrier('90000000-0000-0000-0000-000000000001', 'DEMO - Entrega Central', '+506 8300-1001', 'San José', 'Rosa Mora', 'Cobertura GAM', 'demo-seed', 'Demo local', 'demo-seed');
  perform public.create_carrier('90000000-0000-0000-0000-000000000002', 'DEMO - Transporte Norte', '+506 8300-1002', 'Alajuela', 'Marco Vega', 'Rutas al norte', 'demo-seed', 'Demo local', 'demo-seed');
  perform public.create_carrier('90000000-0000-0000-0000-000000000003', 'DEMO - Envíos del Valle', '+506 8300-1003', 'Heredia', 'Elena Ruiz', 'Paquetería regional', 'demo-seed', 'Demo local', 'demo-seed');
  perform public.create_carrier('90000000-0000-0000-0000-000000000004', 'DEMO - Ruta Pacífico', '+506 8300-1004', 'Puntarenas', 'Jorge Soto', 'Ruta semanal', 'demo-seed', 'Demo local', 'demo-seed');
  perform public.create_carrier('90000000-0000-0000-0000-000000000005', 'DEMO - Entrega Local', '+506 8300-1005', 'Cartago', 'Lucía León', 'Entrega urbana', 'demo-seed', 'Demo local', 'demo-seed');

  select * into v_warehouse from public.warehouses where code = 'DEMO-SECONDARY';
  if not found then
    v_warehouse := public.create_warehouse('DEMO-SECONDARY', 'Bodega demo secundaria', false, 'demo-seed', 'Demo local', 'demo-seed');
  end if;
  if not exists (select 1 from public.inventory_locations where warehouse_id = v_warehouse.id and code = 'DEMO-RECEIVING') then
    perform public.create_inventory_location(v_warehouse.id, 'DEMO-RECEIVING', 'Recepción demo', true, 'demo-seed', 'Demo local', 'demo-seed');
  end if;
  if not exists (select 1 from public.inventory_locations where warehouse_id = v_warehouse.id and code = 'DEMO-SHELF') then
    perform public.create_inventory_location(v_warehouse.id, 'DEMO-SHELF', 'Estantería demo', false, 'demo-seed', 'Demo local', 'demo-seed');
  end if;
end;
$$;

-- Existencia inicial suficiente para simular ventas, más productos agotados,
-- bajo mínimo y saludables para comprobar indicadores de inventario.
do $$
declare
  n integer;
begin
  for n in
    select g from generate_series(1, 100) as s(g)
     where g % 17 <> 0
       and not exists (
         select 1 from public.inventory_documents
          where command_id = ('60000000-0000-0000-0000-' || lpad((1000 + g)::text, 12, '0'))::uuid
       )
  loop
    perform public.create_and_confirm_inventory_document(
      ('60000000-0000-0000-0000-' || lpad((1000 + n)::text, 12, '0'))::uuid,
      'OPENING',
      jsonb_build_array(jsonb_build_object(
        'product_id', ('20000000-0000-0000-0000-' || lpad((1000 + n)::text, 12, '0')),
        'quantity', case when n % 11 = 0 then 3 else 60 + (n % 40) end,
        'notes', 'Carga inicial de producto DEMO'
      )),
      null, null, '30000000-0000-0000-0000-000000000001',
      '31000000-0000-0000-0000-000000000001',
      'DEMO-OPEN-' || lpad(n::text, 3, '0'),
      'Inventario inicial de demostración', 'demo-seed', 'Demo local', 'demo-seed'
    );
  end loop;
end;
$$;

do $$
begin
  if not exists (select 1 from public.inventory_documents where command_id = '86000000-0000-0000-0000-000000000002') then
    perform public.create_and_confirm_inventory_document(
      '86000000-0000-0000-0000-000000000002', 'TRANSFER',
      jsonb_build_array(jsonb_build_object('product_id', '20000000-0000-0000-0000-000000001004', 'quantity', 5, 'notes', 'DEMO: traslado entre bodegas')),
      '30000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001',
      (select id from public.warehouses where code = 'DEMO-SECONDARY'),
      (select id from public.inventory_locations where code = 'DEMO-RECEIVING' and warehouse_id = (select id from public.warehouses where code = 'DEMO-SECONDARY')),
      'DEMO-TRASLADO-001', 'DEMO: traslado en borrador para probar recepción.',
      'demo-seed', 'Demo local', 'demo-seed', true
    );
  end if;
end;
$$;

insert into public.bulk_promotions (
  id, name, discount_percentage, conditions_text, start_date, end_date,
  applies_to_all_products, is_active, created_by, created_device_name, created_device_identifier
)
values
  ('70000000-0000-0000-0000-000000000001', 'DEMO - Organización 10%', 10,
   'Promoción de prueba para categoría Organización.', now() - interval '2 days', now() + interval '30 days', false, true,
   'demo-seed', 'Demo local', 'demo-seed'),
  ('70000000-0000-0000-0000-000000000002', 'DEMO - Accesorios 15%', 15,
   'Promoción de prueba para categoría Accesorios.', now() - interval '1 day', now() + interval '20 days', false, true,
   'demo-seed', 'Demo local', 'demo-seed'),
  ('70000000-0000-0000-0000-000000000003', 'DEMO - Producto destacado 5%', 5,
   'Promoción individual de prueba.', now() - interval '1 day', now() + interval '10 days', false, true,
   'demo-seed', 'Demo local', 'demo-seed')
on conflict (id) do nothing;

insert into public.bulk_promotion_categories (promotion_id, category_id)
values
  ('70000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003'),
  ('70000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000005')
on conflict do nothing;

insert into public.bulk_promotion_products (promotion_id, product_id, conditions_text)
values ('70000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000001001', 'Producto destacado de demostración.')
on conflict do nothing;

-- Cuentas y medios de pago: se insertan con prefijo DEMO sin alterar settings.
insert into public.payment_methods (id, name, created_by, created_device_name, created_device_identifier)
values
  ('80000000-0000-0000-0000-000000000001', 'DEMO - Efectivo', 'demo-seed', 'Demo local', 'demo-seed'),
  ('80000000-0000-0000-0000-000000000002', 'DEMO - Transferencia', 'demo-seed', 'Demo local', 'demo-seed'),
  ('80000000-0000-0000-0000-000000000003', 'DEMO - Tarjeta', 'demo-seed', 'Demo local', 'demo-seed')
on conflict (id) do nothing;

insert into public.money_accounts (id, name, account_type, currency_code, created_by, created_device_name, created_device_identifier)
values
  ('81000000-0000-0000-0000-000000000001', 'DEMO - Caja principal', 'CASH', 'USD', 'demo-seed', 'Demo local', 'demo-seed'),
  ('81000000-0000-0000-0000-000000000002', 'DEMO - Banco USD', 'BANK', 'USD', 'demo-seed', 'Demo local', 'demo-seed'),
  ('81000000-0000-0000-0000-000000000003', 'DEMO - Caja CRC', 'CASH', 'CRC', 'demo-seed', 'Demo local', 'demo-seed')
on conflict (id) do nothing;

insert into public.expenses (id, concept, beneficiary, amount, currency_code, money_account_id, expense_date, created_by, created_device_name, created_device_identifier)
select
  ('84000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
  'DEMO - ' || (array['Material de empaque', 'Transporte local', 'Papelería', 'Limpieza', 'Servicio técnico'])[((n - 1) % 5) + 1],
  'Proveedor Demo ' || lpad(n::text, 2, '0'),
  round((8.25 + n * 3.17)::numeric, 2),
  case when n % 4 = 0 then 'CRC' else 'USD' end,
  case when n % 4 = 0 then '81000000-0000-0000-0000-000000000003'::uuid else '81000000-0000-0000-0000-000000000002'::uuid end,
  current_date - (n % 18), 'demo-seed', 'Demo local', 'demo-seed'
from generate_series(2, 16) as g(n)
on conflict (id) do nothing;

insert into public.unidentified_deposits (id, amount, currency_code, money_account_id, deposit_date, notes, identified, created_by, created_device_name, created_device_identifier)
select
  ('85000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
  round((20 + n * 4.35)::numeric, 2),
  case when n % 3 = 0 then 'CRC' else 'USD' end,
  case when n % 3 = 0 then '81000000-0000-0000-0000-000000000003'::uuid else '81000000-0000-0000-0000-000000000002'::uuid end,
  current_date - (n % 12), 'DEMO: depósito pendiente ' || n, n % 5 = 0,
  'demo-seed', 'Demo local', 'demo-seed'
from generate_series(2, 12) as g(n)
on conflict (id) do nothing;

-- Escrituras documentales no-idempotentes se protegen con IDs y números
-- reservados DEMO. Si ya existen, la sección documental se omite entera.
do $$
declare
  v_customer uuid := '40000000-0000-0000-0000-000000000001';
  v_customer_name text;
  v_agent uuid := '50000000-0000-0000-0000-000000000001';
  v_warehouse uuid := '30000000-0000-0000-0000-000000000001';
  v_location uuid := '31000000-0000-0000-0000-000000000001';
  v_p1 uuid := '20000000-0000-0000-0000-000000001001';
  v_p2 uuid := '20000000-0000-0000-0000-000000001002';
  v_p3 uuid := '20000000-0000-0000-0000-000000001003';
  v_quote_product uuid := '20000000-0000-0000-0000-000000001005';
  v_quote public.sales_quotes%rowtype;
  v_invoice public.sales_invoices%rowtype;
  v_payment uuid;
  v_payment_row public.payments%rowtype;
  v_payment_rate numeric := 0.002;
  v_quote_lines jsonb;
  v_sale_lines jsonb;
  v_lines jsonb;
  v_customer_loop uuid;
  v_customer_loop_name text;
  v_status text;
  i integer;
begin
  select name into v_customer_name from public.customers where id = v_customer;

  v_quote_lines := jsonb_build_array(
    jsonb_build_object('product_id', v_quote_product, 'quantity', 2, 'unit_price', (select unit_price from public.products where id = v_quote_product), 'discount_percent', 0, 'product_sku', (select sku from public.products where id = v_quote_product), 'product_name', (select name from public.products where id = v_quote_product), 'presentation_name', 'Caja 6 unidades', 'units_per_presentation', 6),
    jsonb_build_object('product_id', v_p1, 'quantity', 1, 'unit_price', (select unit_price from public.products where id = v_p1), 'discount_percent', 5, 'product_sku', (select sku from public.products where id = v_p1), 'product_name', (select name from public.products where id = v_p1), 'presentation_name', 'Unidad', 'units_per_presentation', 1)
  );
  if not exists (select 1 from public.sales_quotes where notes like '%[DEMO-COT-001]%') then
    v_quote := public.create_quote(v_customer, v_customer_name, 'USD', 1, current_date + 14,
      'DEMO: cotización de borrador editable. [DEMO-COT-001]', v_agent, v_quote_lines,
      'demo-seed', 'Demo local', 'demo-seed');
  end if;

  if not exists (select 1 from public.sales_quotes where notes like '%[DEMO-COT-002]%') then
    v_quote := public.create_quote(v_customer, v_customer_name, 'USD', 1, current_date + 7,
      'DEMO: cotización enviada. [DEMO-COT-002]', v_agent, v_quote_lines,
      'demo-seed', 'Demo local', 'demo-seed');
    update public.sales_quotes set status = 'SENT' where id = v_quote.id;
  end if;

  if not exists (select 1 from public.sales_quotes where notes like '%[DEMO-COT-003]%') then
    v_quote := public.create_quote(v_customer, v_customer_name, 'USD', 1, current_date + 10,
      'DEMO: aceptada, sin conversión automática todavía. [DEMO-COT-003]', v_agent, v_quote_lines,
      'demo-seed', 'Demo local', 'demo-seed');
    update public.sales_quotes set status = 'ACCEPTED' where id = v_quote.id;
  end if;

  update public.sales_quote_lines l
     set product_id = v_quote_product,
         unit_price = p.unit_price,
         total_price = round(l.quantity * p.unit_price * (1 - l.discount_percent / 100), 2),
         product_sku = p.sku,
         product_name = p.name,
         presentation_name = pp.name,
         units_per_presentation = pp.units_per_presentation
    from public.products p
    join public.packaging_presentations pp on pp.id = p.packaging_presentation_id
   where l.product_id = v_p1
     and p.id = v_quote_product
     and l.quote_id in (select id from public.sales_quotes
                         where created_by = 'demo-seed'
                         and (notes like '%[DEMO-COT-001]%'
                           or notes like '%[DEMO-COT-002]%'
                           or notes like '%[DEMO-COT-003]%'));
  update public.sales_quote_lines l
     set product_id = v_p1,
         unit_price = p.unit_price,
         total_price = round(l.quantity * p.unit_price * (1 - l.discount_percent / 100), 2),
         product_sku = p.sku,
         product_name = p.name,
         presentation_name = pp.name,
         units_per_presentation = pp.units_per_presentation
    from public.products p
    join public.packaging_presentations pp on pp.id = p.packaging_presentation_id
   where l.product_id = v_p2
     and p.id = v_p1
     and l.quote_id in (select id from public.sales_quotes
                         where created_by = 'demo-seed'
                         and (notes like '%[DEMO-COT-001]%'
                           or notes like '%[DEMO-COT-002]%'
                           or notes like '%[DEMO-COT-003]%'));
  update public.sales_quotes q
     set total_amount = (select coalesce(sum(l.total_price), 0)
                           from public.sales_quote_lines l where l.quote_id = q.id)
   where q.created_by = 'demo-seed'
     and (q.notes like '%[DEMO-COT-001]%'
       or q.notes like '%[DEMO-COT-002]%'
       or q.notes like '%[DEMO-COT-003]%');

  v_sale_lines := jsonb_build_array(
    jsonb_build_object('product_id', v_p1, 'quantity', 2, 'unit_price', (select unit_price from public.products where id = v_p1), 'discount_percent', 0, 'product_sku', (select sku from public.products where id = v_p1), 'product_name', (select name from public.products where id = v_p1)),
    jsonb_build_object('product_id', v_p2, 'quantity', 1, 'unit_price', (select unit_price from public.products where id = v_p2), 'discount_percent', 0, 'product_sku', (select sku from public.products where id = v_p2), 'product_name', (select name from public.products where id = v_p2))
  );

  v_invoice := public.create_sale_invoice_with_dispatch(
    '82000000-0000-0000-0000-000000000001'::uuid,
    v_customer, v_customer_name, 'USD'::char(3), 1::numeric,
    'DEMO: factura confirmada con salida de inventario. [DEMO-FAC-001]',
    v_sale_lines, v_warehouse, 'demo-seed', 'Demo local', 'demo-seed'
  );

  if not exists (select 1 from public.sales_orders where notes like '%[DEMO-PED-001]%') then
  perform public.create_order_with_reservation(
    v_customer, v_customer_name, 'USD', 1, 'DEMO: pedido confirmado con despacho. [DEMO-PED-001]',
    v_agent, null, jsonb_build_array(jsonb_build_object(
      'product_id', v_p3, 'quantity', 1, 'unit_price', (select unit_price from public.products where id = v_p3),
      'discount_percent', 0, 'product_sku', (select sku from public.products where id = v_p3),
      'product_name', (select name from public.products where id = v_p3))),
    v_warehouse, v_location, 'demo-seed', 'Demo local', 'demo-seed'
  );
  end if;

  if not exists (select 1 from public.sales_consignments where notes like '%[DEMO-CON-001]%') then
  perform public.create_consignment(
    v_customer, v_customer_name, 'USD', 'DEMO: consignación enviada. [DEMO-CON-001]', v_agent,
    jsonb_build_array(jsonb_build_object(
      'product_id', v_p3, 'quantity', 1, 'unit_price', (select unit_price from public.products where id = v_p3),
      'product_sku', (select sku from public.products where id = v_p3),
      'product_name', (select name from public.products where id = v_p3))),
    v_warehouse, v_location, 'demo-seed', 'Demo local', 'demo-seed'
  );
  end if;

  if not exists (select 1 from public.sales_returns where notes like '%[DEMO-DEV-001]%') then
  perform public.sales_confirm_return(
    '86000000-0000-0000-0000-000000000001'::uuid,
    v_invoice.id,
    'DEMO: empaque abierto.',
    jsonb_build_array(jsonb_build_object(
      'invoice_line_id', (select id from public.sales_invoice_lines
        where invoice_id = v_invoice.id and product_id = v_p2),
      'product_id', v_p2,
      'quantity', (select quantity from public.sales_invoice_lines
        where invoice_id = v_invoice.id and product_id = v_p2),
      'condition', 'GOOD',
      'location_id', v_location
    )),
    'CUSTOMER_CREDIT', 'demo-seed', 'Demo local', 'demo-seed'
  );
  update public.sales_returns set notes = '[DEMO-DEV-001]'
   where command_id = '86000000-0000-0000-0000-000000000001' and notes is null;
  end if;

  if not exists (select 1 from public.payments where notes like '%[DEMO-REC-001]%') then
  v_payment_row := public.create_payment(
    '83000000-0000-0000-0000-000000000001', v_customer_name, 25, 'USD', 1,
    'DEMO: recibo con pago combinado USD/CRC.',
    jsonb_build_array(
      jsonb_build_object('method_id', '80000000-0000-0000-0000-000000000001', 'money_account_id', '81000000-0000-0000-0000-000000000001', 'currency_code', 'USD', 'original_amount', 10, 'exchange_rate', 1, 'usd_equivalent', 10, 'reference', 'DEMO-cash'),
      jsonb_build_object('method_id', '80000000-0000-0000-0000-000000000002', 'money_account_id', '81000000-0000-0000-0000-000000000003', 'currency_code', 'CRC', 'original_amount', 7500, 'exchange_rate', v_payment_rate, 'usd_equivalent', 15, 'reference', 'DEMO-transfer')
    ), 'demo-seed', 'Demo local', 'demo-seed'
  );
  v_payment_row := public.confirm_payment(v_payment_row.id, 'demo-seed', 'Demo local', 'demo-seed');
  v_payment := v_payment_row.id;
  update public.payments set customer_id = v_customer where id = v_payment;
  update public.payments set notes = coalesce(notes, '') || ' [DEMO-REC-001]' where id = v_payment;
  end if;

  for i in 2..12 loop
    if not exists (select 1 from public.payments where notes like '%[DEMO-REC-' || lpad(i::text, 3, '0') || ']%') then
      v_customer_loop := ('40000000-0000-0000-0000-' || lpad(((i - 1) % 24 + 1)::text, 12, '0'))::uuid;
      select name into v_customer_loop_name from public.customers where id = v_customer_loop;
      v_payment_row := public.create_payment(
        ('83000000-0000-0000-0000-' || lpad((1000 + i)::text, 12, '0'))::uuid,
        v_customer_loop_name, 13, 'USD', 1,
        'DEMO: recibo con pago mixto ' || i || ' [DEMO-REC-' || lpad(i::text, 3, '0') || ']',
        jsonb_build_array(
          jsonb_build_object('method_id', '80000000-0000-0000-0000-000000000001', 'money_account_id', '81000000-0000-0000-0000-000000000001', 'currency_code', 'USD', 'original_amount', 8, 'exchange_rate', 1, 'usd_equivalent', 8, 'reference', 'DEMO-cash-' || i),
          jsonb_build_object('method_id', '80000000-0000-0000-0000-000000000002', 'money_account_id', '81000000-0000-0000-0000-000000000003', 'currency_code', 'CRC', 'original_amount', 2500, 'exchange_rate', v_payment_rate, 'usd_equivalent', 5, 'reference', 'DEMO-transfer-' || i)
        ), 'demo-seed', 'Demo local', 'demo-seed');
      v_payment_row := public.confirm_payment(v_payment_row.id, 'demo-seed', 'Demo local', 'demo-seed');
      update public.payments set customer_id = v_customer_loop where id = v_payment_row.id;
      update public.payments set notes = coalesce(notes, '') || ' [DEMO-REC-' || lpad(i::text, 3, '0') || ']'
       where id = v_payment_row.id;
    end if;
  end loop;
  if not exists (select 1 from public.expenses where id = '84000000-0000-0000-0000-000000000001') then
  insert into public.expenses (id, concept, beneficiary, amount, currency_code, money_account_id, expense_date, created_by, created_device_name, created_device_identifier)
  values ('84000000-0000-0000-0000-000000000001', 'DEMO - Material de empaque', 'Proveedor Demo', 18.75, 'USD', '81000000-0000-0000-0000-000000000002', current_date, 'demo-seed', 'Demo local', 'demo-seed')
  on conflict (id) do nothing;
  end if;
  if not exists (select 1 from public.unidentified_deposits where id = '85000000-0000-0000-0000-000000000001') then
  insert into public.unidentified_deposits (id, amount, currency_code, money_account_id, deposit_date, notes, identified, created_by, created_device_name, created_device_identifier)
  values ('85000000-0000-0000-0000-000000000001', 42.00, 'USD', '81000000-0000-0000-0000-000000000002', current_date, 'DEMO: depósito pendiente de identificar.', false, 'demo-seed', 'Demo local', 'demo-seed')
  on conflict (id) do nothing;
  end if;

  for i in 4..18 loop
    if not exists (select 1 from public.sales_quotes where notes like '%[DEMO-COT-' || lpad(i::text, 3, '0') || ']%') then
      v_customer_loop := ('40000000-0000-0000-0000-' || lpad(((i - 1) % 24 + 1)::text, 12, '0'))::uuid;
      select name into v_customer_loop_name from public.customers where id = v_customer_loop;
      v_lines := jsonb_build_array(jsonb_build_object(
        'product_id', ('20000000-0000-0000-0000-' || lpad((1000 + i)::text, 12, '0'))::uuid,
        'quantity', 1 + i % 3,
        'unit_price', (select unit_price from public.products where id = ('20000000-0000-0000-0000-' || lpad((1000 + i)::text, 12, '0'))::uuid),
        'discount_percent', case when i % 4 = 0 then 5 else 0 end,
        'product_sku', (select sku from public.products where id = ('20000000-0000-0000-0000-' || lpad((1000 + i)::text, 12, '0'))::uuid),
        'product_name', (select name from public.products where id = ('20000000-0000-0000-0000-' || lpad((1000 + i)::text, 12, '0'))::uuid),
        'presentation_name', (select pp.name from public.products p join public.packaging_presentations pp on pp.id = p.packaging_presentation_id where p.id = ('20000000-0000-0000-0000-' || lpad((1000 + i)::text, 12, '0'))::uuid),
        'units_per_presentation', (select pp.units_per_presentation from public.products p join public.packaging_presentations pp on pp.id = p.packaging_presentation_id where p.id = ('20000000-0000-0000-0000-' || lpad((1000 + i)::text, 12, '0'))::uuid)
      ));
      v_quote := public.create_quote(v_customer_loop, v_customer_loop_name, 'USD', 1, current_date + 7 + (i % 20),
        'DEMO: cotización de muestra [DEMO-COT-' || lpad(i::text, 3, '0') || ']',
        ('50000000-0000-0000-0000-' || lpad((i % 3 + 1)::text, 12, '0'))::uuid,
        v_lines, 'demo-seed', 'Demo local', 'demo-seed');
      v_status := case i % 4 when 0 then 'SENT' when 1 then 'DRAFT' when 2 then 'REJECTED' else 'EXPIRED' end;
      if v_status <> 'DRAFT' then
        perform public.update_quote_status(v_quote.id, v_status, 'demo-seed', 'Demo local', 'demo-seed');
      end if;
    end if;
  end loop;

  for i in 2..8 loop
    v_customer_loop := ('40000000-0000-0000-0000-' || lpad((i::text), 12, '0'))::uuid;
    select name into v_customer_loop_name from public.customers where id = v_customer_loop;
    v_p1 := ('20000000-0000-0000-0000-' || lpad((1000 + i)::text, 12, '0'))::uuid;
    v_lines := jsonb_build_array(jsonb_build_object(
      'product_id', v_p1, 'quantity', 2,
      'unit_price', (select unit_price from public.products where id = v_p1),
      'discount_percent', 0, 'product_sku', (select sku from public.products where id = v_p1),
      'product_name', (select name from public.products where id = v_p1)
    ));
    v_invoice := public.create_sale_invoice_with_dispatch(
      ('82000000-0000-0000-0000-' || lpad((2000 + i)::text, 12, '0'))::uuid,
      v_customer_loop, v_customer_loop_name, 'USD'::char(3), 1::numeric,
      'DEMO: factura confirmada ' || i || ' [DEMO-FAC-' || lpad(i::text, 3, '0') || ']',
      v_lines, v_warehouse, 'demo-seed', 'Demo local', 'demo-seed');
    if not exists (select 1 from public.sales_returns where notes like '%[DEMO-DEV-' || lpad(i::text, 3, '0') || ']%') then
      perform public.sales_confirm_return(
        ('86000000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid,
        v_invoice.id,
        'DEMO: devolución de factura ' || i,
        jsonb_build_array(jsonb_build_object(
          'invoice_line_id', (select id from public.sales_invoice_lines
            where invoice_id = v_invoice.id and product_id = v_p1),
          'product_id', v_p1,
          'quantity', (select quantity from public.sales_invoice_lines
            where invoice_id = v_invoice.id and product_id = v_p1),
          'condition', 'GOOD',
          'location_id', v_location
        )),
        'CUSTOMER_CREDIT', 'demo-seed', 'Demo local', 'demo-seed'
      );
      update public.sales_returns set notes = '[DEMO-DEV-' || lpad(i::text, 3, '0') || ']'
       where command_id = ('86000000-0000-0000-0000-' || lpad(i::text, 12, '0'))::uuid
         and notes is null;
    end if;
  end loop;

  for i in 2..12 loop
    v_customer_loop := ('40000000-0000-0000-0000-' || lpad((i::text), 12, '0'))::uuid;
    select name into v_customer_loop_name from public.customers where id = v_customer_loop;
    v_p2 := ('20000000-0000-0000-0000-' || lpad((1020 + i)::text, 12, '0'))::uuid;
    v_lines := jsonb_build_array(jsonb_build_object(
      'product_id', v_p2, 'quantity', 1 + i % 2,
      'unit_price', (select unit_price from public.products where id = v_p2),
      'discount_percent', 0, 'product_sku', (select sku from public.products where id = v_p2),
      'product_name', (select name from public.products where id = v_p2)
    ));
    if not exists (select 1 from public.sales_orders where notes like '%[DEMO-PED-' || lpad(i::text, 3, '0') || ']%') then
      perform public.create_order_with_reservation(v_customer_loop, v_customer_loop_name, 'USD', 1,
        'DEMO: pedido confirmado ' || i || ' [DEMO-PED-' || lpad(i::text, 3, '0') || ']',
        ('50000000-0000-0000-0000-' || lpad((i % 3 + 1)::text, 12, '0'))::uuid,
        null, v_lines, v_warehouse, v_location, 'demo-seed', 'Demo local', 'demo-seed');
    end if;
    if not exists (select 1 from public.sales_consignments where notes like '%[DEMO-CON-' || lpad(i::text, 3, '0') || ']%') then
      perform public.create_consignment(v_customer_loop, v_customer_loop_name, 'USD',
        'DEMO: consignación enviada ' || i || ' [DEMO-CON-' || lpad(i::text, 3, '0') || ']',
        ('50000000-0000-0000-0000-' || lpad((i % 3 + 1)::text, 12, '0'))::uuid,
        v_lines, v_warehouse, v_location, 'demo-seed', 'Demo local', 'demo-seed');
    end if;
  end loop;
end;
$$;

-- Borradores de inventario son soportados: se crean con la RPC oficial y no
-- mueven existencias hasta confirmarse en la pantalla.
do $$
begin
  if not exists (select 1 from public.inventory_documents where command_id = '86000000-0000-0000-0000-000000000001') then
    perform public.create_and_confirm_inventory_document(
      '86000000-0000-0000-0000-000000000001', 'ADJUSTMENT',
      jsonb_build_array(jsonb_build_object('product_id', '20000000-0000-0000-0000-000000001004', 'quantity', 4, 'notes', 'DEMO: borrador de ajuste')),
      null, null, '30000000-0000-0000-0000-000000000001', '31000000-0000-0000-0000-000000000001',
      'DEMO-AJUSTE-001', 'DEMO: ajuste en borrador', 'demo-seed', 'Demo local', 'demo-seed', true
    );
  end if;
end;
$$;

do $$
begin
  if (select count(*) from public.products where sku like 'DEMO-%') < 100 then
    raise exception 'Dataset incompleto: se requieren al menos 100 productos DEMO';
  end if;
  if (select count(*) from public.categories where id between '10000000-0000-0000-0000-000000000001'::uuid and '10000000-0000-0000-0000-000000000005'::uuid) < 5 then
    raise exception 'Dataset incompleto: faltan categorías DEMO';
  end if;
end;
$$;

commit;
