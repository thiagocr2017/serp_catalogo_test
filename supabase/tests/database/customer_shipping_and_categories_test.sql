begin;

select plan(9);

-- 1. Verifica tablas y columnas
select ok(has_table_privilege('anon', 'public.customer_categories', 'SELECT'), 'anon can select customer_categories');
select ok(has_table_privilege('anon', 'public.customer_category_assignments', 'SELECT'), 'anon can select customer_category_assignments');

-- 2. Verifica categorias iniciales precargadas
select ok(
  (select count(*) >= 5 from public.customer_categories where is_active),
  'existen al menos 5 categorias de cliente iniciales'
);

-- 3. Crear categoría personalizada
select ok(
  (select id is not null from public.create_customer_category('VIP', 'Clientes preferenciales', '#FFD700')),
  'create_customer_category crea categoria correctamente'
);

-- 4. Crear cliente con política de envío y categoría asignada
create temp table _cat_ids as
select array_agg(id) as ids from public.customer_categories where name in ('Mayorista', 'VIP');

select public.create_customer(
  p_name := 'Cliente Shipping Policy Test',
  p_display_name := null,
  p_phone := '88881234',
  p_email := 'shipping@example.com',
  p_address := 'San José',
  p_tax_id := null,
  p_credit_limit := 0,
  p_country_code := 'CR',
  p_province := 'San José',
  p_city := null,
  p_gira := null,
  p_preferred_carrier_id := null,
  p_customer_type := 'CASH',
  p_credit_days := null,
  p_document_preference := 'TICKET',
  p_requires_e_invoice := false,
  p_identification_type_id := null,
  p_economic_activity := null,
  p_actor_name := 'Tester',
  p_device_name := 'Device',
  p_device_identifier := 'dev',
  p_shipping_payment_policy := 'CASH_ON_DELIVERY',
  p_category_ids := (select ids from _cat_ids)
);

create temp table _created_cust as
select * from public.customers where name = 'Cliente Shipping Policy Test' limit 1;

select is(
  (select shipping_payment_policy from _created_cust),
  'CASH_ON_DELIVERY',
  'cliente guarda shipping_payment_policy correctamente'
);

select is(
  (select count(*)::int from public.customer_category_assignments where customer_id = (select id from _created_cust)),
  2,
  'cliente tiene 2 categorias asignadas'
);

-- 5. Actualizar política de envío y categorías
select public.update_customer(
  p_customer_id := (select id from _created_cust),
  p_name := 'Cliente Shipping Policy Modificado',
  p_display_name := null,
  p_phone := '88881234',
  p_email := 'shipping@example.com',
  p_address := 'San José',
  p_tax_id := null,
  p_credit_limit := 0,
  p_country_code := 'CR',
  p_province := 'San José',
  p_city := null,
  p_gira := null,
  p_preferred_carrier_id := null,
  p_customer_type := 'CASH',
  p_credit_days := null,
  p_document_preference := 'TICKET',
  p_requires_e_invoice := false,
  p_identification_type_id := null,
  p_economic_activity := null,
  p_actor_name := 'Tester',
  p_device_name := 'Device',
  p_device_identifier := 'dev',
  p_shipping_payment_policy := 'PREPAID',
  p_category_ids := array[(select id from public.customer_categories where name = 'Detallista')]
);

select is(
  (select shipping_payment_policy from public.customers where id = (select id from _created_cust)),
  'PREPAID',
  'update_customer actualiza shipping_payment_policy a PREPAID'
);

select is(
  (select count(*)::int from public.customer_category_assignments where customer_id = (select id from _created_cust)),
  1,
  'update_customer reemplaza asignaciones de categoria correctamente'
);

-- 6. customer_commercial_summary incluye categorías
select ok(
  (
    select jsonb_array_length(public.customer_commercial_summary((select id from _created_cust))->'categories') = 1
  ),
  'customer_commercial_summary retorna las categorias asignadas'
);

select * from finish();
rollback;
