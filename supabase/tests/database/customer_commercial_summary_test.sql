begin;

select plan(5);

-- 1. Verifica que la función exista y tenga permisos
select ok(has_function_privilege('anon', 'public.customer_commercial_summary(uuid)', 'EXECUTE'), 'anon ejecuta customer_commercial_summary');
select ok(has_function_privilege('authenticated', 'public.customer_commercial_summary(uuid)', 'EXECUTE'), 'authenticated ejecuta customer_commercial_summary');

-- 2. Crear cliente de prueba
select public.create_customer(
  p_name := 'Cliente Resumen Test',
  p_display_name := 'Resumen Test',
  p_phone := '88887777',
  p_email := 'resumen@example.com',
  p_address := 'San José',
  p_tax_id := '3-101-999999',
  p_credit_limit := 1000.0,
  p_country_code := 'CR',
  p_province := 'San José',
  p_city := null,
  p_gira := 'Gira 1',
  p_preferred_carrier_id := null,
  p_customer_type := 'CASH',
  p_credit_days := null,
  p_document_preference := 'E_INVOICE',
  p_requires_e_invoice := false,
  p_identification_type_id := null,
  p_economic_activity := null,
  p_actor_name := 'Tester',
  p_device_name := 'TestDevice',
  p_device_identifier := 'dev-1'
);

create temp table _test_customer as
select id from public.customers where name = 'Cliente Resumen Test' limit 1;

-- 3. Probar ejecución del RPC en cliente sin compras (estado vacío)
select ok(
  (
    select (public.customer_commercial_summary((select id from _test_customer))->>'total_invoiced')::numeric = 0
  ),
  'cliente sin compras tiene total facturado 0'
);

select ok(
  (
    select (public.customer_commercial_summary((select id from _test_customer))->>'total_pending_documents')::int = 0
  ),
  'cliente sin documentos tiene pendientes en 0'
);

select ok(
  (
    select jsonb_array_length((public.customer_commercial_summary((select id from _test_customer))->'frequent_products')) = 0
  ),
  'cliente sin compras tiene lista de productos frecuentes vacía'
);

select * from finish();
rollback;
