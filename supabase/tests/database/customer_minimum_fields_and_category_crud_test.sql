begin;

select plan(118);

create function pg_temp.create_test_customer(
  p_name text default 'DB Contract Customer',
  p_display_name text default 'DB Contract Shop',
  p_phone text default '88881111',
  p_address text default 'Avenida Central',
  p_gira text default 'Gira Central',
  p_customer_type text default 'CASH',
  p_credit_days integer default null,
  p_email text default null,
  p_tax_id text default null,
  p_requires_e_invoice boolean default false,
  p_identification_type_id uuid default null,
  p_economic_activity text default null,
  p_shipping_payment_policy text default 'INCLUDED',
  p_preferred_carrier_id uuid default null,
  p_category_ids uuid[] default '{}'::uuid[]
) returns uuid
language sql
as $$
  select (public.create_customer(
    p_name := p_name,
    p_display_name := p_display_name,
    p_phone := p_phone,
    p_email := p_email,
    p_address := p_address,
    p_tax_id := p_tax_id,
    p_credit_limit := 0,
    p_country_code := 'CR',
    p_province := 'San José',
    p_city := null,
    p_gira := p_gira,
    p_preferred_carrier_id := p_preferred_carrier_id,
    p_customer_type := p_customer_type,
    p_credit_days := p_credit_days,
    p_document_preference := 'TICKET',
    p_requires_e_invoice := p_requires_e_invoice,
    p_identification_type_id := p_identification_type_id,
    p_economic_activity := p_economic_activity,
    p_actor_name := 'pgTAP',
    p_device_name := 'pgTAP device',
    p_device_identifier := 'pgtap-customer-db-contract',
    p_shipping_payment_policy := p_shipping_payment_policy,
    p_category_ids := p_category_ids
  )).id
$$;

create function pg_temp.update_test_customer(
  p_id uuid,
  p_name text default 'DB Contract Customer Updated',
  p_display_name text default 'DB Contract Shop Updated',
  p_phone text default '88882222',
  p_address text default 'Calle Central',
  p_gira text default 'Gira Norte',
  p_customer_type text default 'CASH',
  p_credit_days integer default null,
  p_email text default null,
  p_tax_id text default null,
  p_requires_e_invoice boolean default false,
  p_identification_type_id uuid default null,
  p_economic_activity text default null,
  p_shipping_payment_policy text default 'INCLUDED',
  p_preferred_carrier_id uuid default null,
  p_category_ids uuid[] default null
) returns public.customers
language sql
as $$
  select public.update_customer(
    p_customer_id := p_id,
    p_name := p_name,
    p_display_name := p_display_name,
    p_phone := p_phone,
    p_email := p_email,
    p_address := p_address,
    p_tax_id := p_tax_id,
    p_credit_limit := 0,
    p_country_code := 'CR',
    p_province := 'San José',
    p_city := null,
    p_gira := p_gira,
    p_preferred_carrier_id := p_preferred_carrier_id,
    p_customer_type := p_customer_type,
    p_credit_days := p_credit_days,
    p_document_preference := 'TICKET',
    p_requires_e_invoice := p_requires_e_invoice,
    p_identification_type_id := p_identification_type_id,
    p_economic_activity := p_economic_activity,
    p_actor_name := 'pgTAP',
    p_device_name := 'pgTAP device',
    p_device_identifier := 'pgtap-customer-db-contract',
    p_shipping_payment_policy := p_shipping_payment_policy,
    p_category_ids := p_category_ids
  )
$$;

-- RPC grants and direct table access.
select has_table('public', 'customer_categories', 'existe el catalogo de categorias');
select has_table('public', 'customer_category_assignments', 'existe la relacion cliente-categoria');
select columns_are('public', 'customer_categories', array['id', 'name', 'description', 'color', 'is_active', 'created_at', 'updated_at'], 'customer_categories mantiene sus columnas');
select columns_are('public', 'customer_category_assignments', array['customer_id', 'category_id', 'assigned_at'], 'customer_category_assignments mantiene sus columnas');
select has_pk('public', 'customer_categories', 'customer_categories tiene llave primaria');
select has_pk('public', 'customer_category_assignments', 'asignaciones tienen llave primaria compuesta');
select has_index('public', 'customer_categories', 'customer_categories_name_lower_idx', 'nombres de categoria tienen indice unico normalizado');
select ok(has_function_privilege('anon', 'public.create_customer_category(text, text, text)', 'EXECUTE'), 'anon ejecuta create_customer_category');
select ok(has_function_privilege('authenticated', 'public.create_customer_category(text, text, text)', 'EXECUTE'), 'authenticated ejecuta create_customer_category');
select ok(has_function_privilege('anon', 'public.update_customer_category(uuid, text, text, text, boolean)', 'EXECUTE'), 'anon ejecuta update_customer_category');
select ok(has_function_privilege('authenticated', 'public.update_customer_category(uuid, text, text, text, boolean)', 'EXECUTE'), 'authenticated ejecuta update_customer_category');
select ok(has_function_privilege('anon', 'public.delete_customer_category(uuid)', 'EXECUTE'), 'anon ejecuta delete_customer_category');
select ok(has_function_privilege('authenticated', 'public.delete_customer_category(uuid)', 'EXECUTE'), 'authenticated ejecuta delete_customer_category');
select ok(has_table_privilege('anon', 'public.customer_categories', 'SELECT'), 'anon lee customer_categories');
select ok(has_table_privilege('authenticated', 'public.customer_categories', 'SELECT'), 'authenticated lee customer_categories');
select ok(has_table_privilege('anon', 'public.customer_category_assignments', 'SELECT'), 'anon lee asignaciones de categoria');
select ok(has_table_privilege('authenticated', 'public.customer_category_assignments', 'SELECT'), 'authenticated lee asignaciones de categoria');
select ok(not has_table_privilege('anon', 'public.customer_categories', 'INSERT,UPDATE,DELETE'), 'anon no escribe customer_categories directamente');
select ok(not has_table_privilege('authenticated', 'public.customer_categories', 'INSERT,UPDATE,DELETE'), 'authenticated no escribe customer_categories directamente');
select ok(not has_table_privilege('anon', 'public.customer_category_assignments', 'INSERT,UPDATE,DELETE'), 'anon no escribe asignaciones directamente');
select ok(not has_table_privilege('authenticated', 'public.customer_category_assignments', 'INSERT,UPDATE,DELETE'), 'authenticated no escribe asignaciones directamente');

select ok((select proconfig is not null and array_to_string(proconfig, ',') like '%search_path=%' from pg_proc where oid = 'public.update_customer_category(uuid, text, text, text, boolean)'::regprocedure), 'update_customer_category fija search_path');
select ok((select proconfig is not null and array_to_string(proconfig, ',') like '%search_path=%' from pg_proc where oid = 'public.delete_customer_category(uuid)'::regprocedure), 'delete_customer_category fija search_path');
select ok((select proconfig is not null and array_to_string(proconfig, ',') like '%search_path=%' from pg_proc where oid = 'public.create_customer_category(text, text, text)'::regprocedure), 'create_customer_category fija search_path');

-- Every minimum field rejects NULL, empty text and whitespace on create.
select throws_ok($$select pg_temp.create_test_customer(p_name := null)$$, 'P0001', 'NAME_REQUIRED', 'create rechaza nombre fiscal NULL');
select throws_ok($$select pg_temp.create_test_customer(p_name := '')$$, 'P0001', 'NAME_REQUIRED', 'create rechaza nombre fiscal vacio');
select throws_ok($$select pg_temp.create_test_customer(p_name := '   ')$$, 'P0001', 'NAME_REQUIRED', 'create rechaza nombre fiscal con espacios');
select throws_ok($$select pg_temp.create_test_customer(p_display_name := null)$$, 'P0001', 'DISPLAY_NAME_REQUIRED', 'create rechaza fantasia NULL');
select throws_ok($$select pg_temp.create_test_customer(p_display_name := '')$$, 'P0001', 'DISPLAY_NAME_REQUIRED', 'create rechaza fantasia vacia');
select throws_ok($$select pg_temp.create_test_customer(p_display_name := '   ')$$, 'P0001', 'DISPLAY_NAME_REQUIRED', 'create rechaza fantasia con espacios');
select throws_ok($$select pg_temp.create_test_customer(p_phone := null)$$, 'P0001', 'PHONE_REQUIRED', 'create rechaza telefono NULL');
select throws_ok($$select pg_temp.create_test_customer(p_phone := '')$$, 'P0001', 'PHONE_REQUIRED', 'create rechaza telefono vacio');
select throws_ok($$select pg_temp.create_test_customer(p_phone := '   ')$$, 'P0001', 'PHONE_REQUIRED', 'create rechaza telefono con espacios');
select throws_ok($$select pg_temp.create_test_customer(p_gira := null)$$, 'P0001', 'GIRA_REQUIRED', 'create rechaza gira NULL');
select throws_ok($$select pg_temp.create_test_customer(p_gira := '')$$, 'P0001', 'GIRA_REQUIRED', 'create rechaza gira vacia');
select throws_ok($$select pg_temp.create_test_customer(p_gira := '   ')$$, 'P0001', 'GIRA_REQUIRED', 'create rechaza gira con espacios');
select throws_ok($$select pg_temp.create_test_customer(p_address := null)$$, 'P0001', 'ADDRESS_REQUIRED', 'create rechaza direccion NULL');
select throws_ok($$select pg_temp.create_test_customer(p_address := '')$$, 'P0001', 'ADDRESS_REQUIRED', 'create rechaza direccion vacia');
select throws_ok($$select pg_temp.create_test_customer(p_address := '   ')$$, 'P0001', 'ADDRESS_REQUIRED', 'create rechaza direccion con espacios');

create temp table _customer_fixture as
select pg_temp.create_test_customer(
  '  Empresa SA  ', '  Mi Tienda  ', ' 88881111 ', ' Av Central 1 ', ' Gira Central '
) as id;

select is((select name from public.customers where id = (select id from _customer_fixture)), 'Empresa SA', 'create acepta cliente valido y normaliza nombre fiscal');
select is((select display_name from public.customers where id = (select id from _customer_fixture)), 'Mi Tienda', 'create elimina espacios exteriores de fantasia');
select is((select phone from public.customers where id = (select id from _customer_fixture)), '88881111', 'create elimina espacios exteriores del telefono');
select is((select address from public.customers where id = (select id from _customer_fixture)), 'Av Central 1', 'create elimina espacios exteriores de direccion');
select is((select gira from public.customers where id = (select id from _customer_fixture)), 'Gira Central', 'create elimina espacios exteriores de gira');
select is((select count(*)::integer from public.customers where id = (select id from _customer_fixture)), 1, 'fallos de create no dejan filas parciales y el cliente valido existe');

-- Every minimum field rejects NULL, empty text and whitespace on update.
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_name := null)$$, 'P0001', 'NAME_REQUIRED', 'update rechaza nombre fiscal NULL');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_name := '')$$, 'P0001', 'NAME_REQUIRED', 'update rechaza nombre fiscal vacio');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_name := '   ')$$, 'P0001', 'NAME_REQUIRED', 'update rechaza nombre fiscal con espacios');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_display_name := null)$$, 'P0001', 'DISPLAY_NAME_REQUIRED', 'update rechaza fantasia NULL');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_display_name := '')$$, 'P0001', 'DISPLAY_NAME_REQUIRED', 'update rechaza fantasia vacia');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_display_name := '   ')$$, 'P0001', 'DISPLAY_NAME_REQUIRED', 'update rechaza fantasia con espacios');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_phone := null)$$, 'P0001', 'PHONE_REQUIRED', 'update rechaza telefono NULL');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_phone := '')$$, 'P0001', 'PHONE_REQUIRED', 'update rechaza telefono vacio');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_phone := '   ')$$, 'P0001', 'PHONE_REQUIRED', 'update rechaza telefono con espacios');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_gira := null)$$, 'P0001', 'GIRA_REQUIRED', 'update rechaza gira NULL');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_gira := '')$$, 'P0001', 'GIRA_REQUIRED', 'update rechaza gira vacia');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_gira := '   ')$$, 'P0001', 'GIRA_REQUIRED', 'update rechaza gira con espacios');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_address := null)$$, 'P0001', 'ADDRESS_REQUIRED', 'update rechaza direccion NULL');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_address := '')$$, 'P0001', 'ADDRESS_REQUIRED', 'update rechaza direccion vacia');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_address := '   ')$$, 'P0001', 'ADDRESS_REQUIRED', 'update rechaza direccion con espacios');
select is(
  (select jsonb_build_object('name', name, 'display_name', display_name, 'phone', phone, 'address', address, 'gira', gira)
     from public.customers where id = (select id from _customer_fixture)),
  '{"name":"Empresa SA","display_name":"Mi Tienda","phone":"88881111","address":"Av Central 1","gira":"Gira Central"}'::jsonb,
  'errores de update preservan todos los valores anteriores'
);

select is((pg_temp.update_test_customer((select id from _customer_fixture))).name, 'DB Contract Customer Updated', 'update acepta minimos validos');
select is((select display_name from public.customers where id = (select id from _customer_fixture)), 'DB Contract Shop Updated', 'update persiste fantasia');

-- Credit requirements are enforced at the persistence boundary.
select throws_ok($$select pg_temp.create_test_customer(p_name := 'Credit No Days', p_customer_type := 'CREDIT', p_credit_days := null)$$, 'P0001', 'CREDIT_DAYS_REQUIRED', 'create credito exige dias');
select throws_ok($$select pg_temp.create_test_customer(p_name := 'Credit Zero Days', p_customer_type := 'CREDIT', p_credit_days := 0)$$, 'P0001', 'CREDIT_DAYS_REQUIRED', 'create credito rechaza cero dias');
select throws_ok($$select pg_temp.create_test_customer(p_name := 'Credit Negative Days', p_customer_type := 'CREDIT', p_credit_days := -1)$$, 'P0001', 'CREDIT_DAYS_REQUIRED', 'create credito rechaza dias negativos');
create temp table _credit_fixture as
select pg_temp.create_test_customer(p_name := 'Credit Valid', p_customer_type := 'CREDIT', p_credit_days := 30) as id;
select is((select credit_days from public.customers where id = (select id from _credit_fixture)), 30, 'create credito acepta dias positivos');
select throws_ok($$select pg_temp.update_test_customer((select id from _credit_fixture), p_customer_type := 'CREDIT', p_credit_days := null)$$, 'P0001', 'CREDIT_DAYS_REQUIRED', 'update credito exige dias');
select throws_ok($$select pg_temp.update_test_customer((select id from _credit_fixture), p_customer_type := 'CREDIT', p_credit_days := 0)$$, 'P0001', 'CREDIT_DAYS_REQUIRED', 'update credito rechaza cero dias');
select throws_ok($$select pg_temp.update_test_customer((select id from _credit_fixture), p_customer_type := 'CREDIT', p_credit_days := -1)$$, 'P0001', 'CREDIT_DAYS_REQUIRED', 'update credito rechaza dias negativos');
select is((select credit_days from public.customers where id = (select id from _credit_fixture)), 30, 'update credito invalido preserva dias anteriores');
select is((pg_temp.update_test_customer((select id from _credit_fixture), p_customer_type := 'CREDIT', p_credit_days := 45)).credit_days, 45, 'update credito acepta dias positivos');

-- E-invoice requirements are enforced on create and update.
select throws_ok($$select pg_temp.create_test_customer(p_name := 'Fiscal No Tax', p_requires_e_invoice := true, p_tax_id := null, p_identification_type_id := (select id from public.identification_types where code = 'NITE'), p_email := 'fiscal@example.com', p_economic_activity := 'Servicios')$$, 'P0001', 'E_INVOICE_TAX_ID_REQUIRED', 'create factura electronica exige identificacion');
select throws_ok($$select pg_temp.create_test_customer(p_name := 'Fiscal No Type', p_requires_e_invoice := true, p_tax_id := '123', p_identification_type_id := null, p_email := 'fiscal@example.com', p_economic_activity := 'Servicios')$$, 'P0001', 'E_INVOICE_IDENTIFICATION_TYPE_REQUIRED', 'create factura electronica exige tipo de identificacion');
select throws_ok($$select pg_temp.create_test_customer(p_name := 'Fiscal No Email', p_requires_e_invoice := true, p_tax_id := '123', p_identification_type_id := (select id from public.identification_types where code = 'NITE'), p_email := null, p_economic_activity := 'Servicios')$$, 'P0001', 'E_INVOICE_EMAIL_REQUIRED', 'create factura electronica exige correo');
select throws_ok($$select pg_temp.create_test_customer(p_name := 'Fiscal No Activity', p_requires_e_invoice := true, p_tax_id := '123', p_identification_type_id := (select id from public.identification_types where code = 'NITE'), p_email := 'fiscal@example.com', p_economic_activity := null)$$, 'P0001', 'E_INVOICE_ECONOMIC_ACTIVITY_REQUIRED', 'create factura electronica exige actividad economica');
create temp table _fiscal_fixture as
select pg_temp.create_test_customer(p_name := 'Fiscal Valid', p_email := 'fiscal@example.com', p_tax_id := '3101000000', p_requires_e_invoice := true, p_identification_type_id := (select id from public.identification_types where code = 'NITE'), p_economic_activity := 'Servicios') as id;
select throws_ok($$select pg_temp.update_test_customer((select id from _fiscal_fixture), p_requires_e_invoice := true, p_tax_id := null, p_identification_type_id := (select id from public.identification_types where code = 'NITE'), p_email := 'fiscal@example.com', p_economic_activity := 'Servicios')$$, 'P0001', 'E_INVOICE_TAX_ID_REQUIRED', 'update factura electronica exige identificacion');
select throws_ok($$select pg_temp.update_test_customer((select id from _fiscal_fixture), p_requires_e_invoice := true, p_tax_id := '3101000000', p_identification_type_id := null, p_email := 'fiscal@example.com', p_economic_activity := 'Servicios')$$, 'P0001', 'E_INVOICE_IDENTIFICATION_TYPE_REQUIRED', 'update factura electronica exige tipo de identificacion');
select throws_ok($$select pg_temp.update_test_customer((select id from _fiscal_fixture), p_requires_e_invoice := true, p_tax_id := '3101000000', p_identification_type_id := (select id from public.identification_types where code = 'NITE'), p_email := null, p_economic_activity := 'Servicios')$$, 'P0001', 'E_INVOICE_EMAIL_REQUIRED', 'update factura electronica exige correo');
select throws_ok($$select pg_temp.update_test_customer((select id from _fiscal_fixture), p_requires_e_invoice := true, p_tax_id := '3101000000', p_identification_type_id := (select id from public.identification_types where code = 'NITE'), p_email := 'fiscal@example.com', p_economic_activity := null)$$, 'P0001', 'E_INVOICE_ECONOMIC_ACTIVITY_REQUIRED', 'update factura electronica exige actividad economica');
select is((select tax_id || ':' || economic_activity from public.customers where id = (select id from _fiscal_fixture)), '3101000000:Servicios', 'errores fiscales de update preservan datos anteriores');

-- Catalog references and shipping policy remain constrained by RPCs.
select throws_ok($$select pg_temp.create_test_customer(p_name := 'Carrier Invalid', p_preferred_carrier_id := '00000000-0000-0000-0000-000000000000')$$, 'P0001', 'CARRIER_INACTIVE', 'create rechaza transporte inexistente o inactivo');
select throws_ok($$select pg_temp.create_test_customer(p_name := 'Policy Invalid', p_shipping_payment_policy := 'LATER')$$, 'P0001', 'INVALID_SHIPPING_PAYMENT_POLICY', 'create rechaza politica de envio invalida');
select is((select shipping_payment_policy from public.customers where id = (select id from _customer_fixture)), 'INCLUDED', 'create usa INCLUDED como politica de envio por defecto');
select is(pg_temp.create_test_customer(p_name := 'Policy Prepaid', p_shipping_payment_policy := 'PREPAID') is not null, true, 'create acepta politica PREPAID');
select is(pg_temp.create_test_customer(p_name := 'Policy COD', p_shipping_payment_policy := 'CASH_ON_DELIVERY') is not null, true, 'create acepta politica CASH_ON_DELIVERY');
select throws_ok($$select pg_temp.update_test_customer((select id from _customer_fixture), p_shipping_payment_policy := 'LATER')$$, 'P0001', 'INVALID_SHIPPING_PAYMENT_POLICY', 'update rechaza politica de envio invalida');
select is((select shipping_payment_policy from public.customers where id = (select id from _customer_fixture)), 'INCLUDED', 'error de envio en update preserva politica anterior');

-- Category CRUD validation, normalization, usage guard, and atomic failures.
select throws_ok($$select public.create_customer_category(null, null, null)$$, 'P0001', 'INVALID_INPUT', 'create categoria rechaza nombre NULL');
select throws_ok($$select public.create_customer_category('', null, null)$$, 'P0001', 'INVALID_INPUT', 'create categoria rechaza nombre vacio');
select throws_ok($$select public.create_customer_category('   ', null, null)$$, 'P0001', 'INVALID_INPUT', 'create categoria rechaza nombre con espacios');
select throws_ok($$select public.update_customer_category('00000000-0000-0000-0000-000000000000', 'Nombre')$$, 'P0001', 'CATEGORY_NOT_FOUND', 'update categoria rechaza ID inexistente');
select throws_ok($$select public.delete_customer_category('00000000-0000-0000-0000-000000000000')$$, 'P0001', 'CATEGORY_NOT_FOUND', 'delete categoria rechaza ID inexistente');

create temp table _category_fixture as
select (public.create_customer_category('  Categoria Temporal  ', '  Descripcion  ', '  #123456  ')).id as id;
create temp table _category_second as
select (public.create_customer_category('Categoria Secundaria')).id as id;
select is((select name from public.customer_categories where id = (select id from _category_fixture)), 'Categoria Temporal', 'create categoria normaliza nombre');
select is((select description from public.customer_categories where id = (select id from _category_fixture)), 'Descripcion', 'create categoria normaliza descripcion');
select is((select color from public.customer_categories where id = (select id from _category_fixture)), '#123456', 'create categoria normaliza color');
create temp table _category_empty_optional as
select (public.create_customer_category('Categoria Opcionales', '   ', '')).id as id;
select is((select description from public.customer_categories where id = (select id from _category_empty_optional)), null::text, 'create categoria convierte descripcion vacia en NULL');
select is((select color from public.customer_categories where id = (select id from _category_empty_optional)), null::text, 'create categoria convierte color vacio en NULL');
select is(public.delete_customer_category((select id from _category_empty_optional)), true, 'limpia categoria temporal de opcionales');

select throws_ok($$select public.update_customer_category((select id from _category_fixture), '   ', 'cambio', '#ffffff', false)$$, 'P0001', 'INVALID_INPUT', 'update categoria rechaza nombre en blanco');
select is((select name from public.customer_categories where id = (select id from _category_fixture)), 'Categoria Temporal', 'error de update categoria no cambia la fila');
select is((public.update_customer_category((select id from _category_fixture), '  Categoria Editada  ', '  Nueva descripcion  ', '  #654321  ', false)).name, 'Categoria Editada', 'update categoria normaliza y actualiza nombre');
select is((select description from public.customer_categories where id = (select id from _category_fixture)), 'Nueva descripcion', 'update categoria normaliza descripcion');
select is((select color from public.customer_categories where id = (select id from _category_fixture)), '#654321', 'update categoria normaliza color');
select public.update_customer_category((select id from _category_fixture), 'Categoria Editada', '   ', '', false);
select is((select description from public.customer_categories where id = (select id from _category_fixture)), null::text, 'update categoria convierte descripcion vacia en NULL');
select is((select color from public.customer_categories where id = (select id from _category_fixture)), null::text, 'update categoria convierte color vacio en NULL');
select ok(not (select is_active from public.customer_categories where id = (select id from _category_fixture)), 'update categoria permite desactivar');
select ok((public.update_customer_category((select id from _category_fixture), 'Categoria Editada', null, null, true)).is_active, 'update categoria permite reactivar');

create temp table _category_assignment_customer as
select pg_temp.create_test_customer(
  p_name := 'Category Assignment Customer',
  p_category_ids := array[(select id from _category_fixture), (select id from _category_second), (select id from _category_fixture)]
) as id;
select is((select count(*)::integer from public.customer_category_assignments where customer_id = (select id from _category_assignment_customer)), 2, 'create asigna categorias multiples y elimina IDs repetidos');
select pg_temp.update_test_customer((select id from _category_assignment_customer));
select is((select count(*)::integer from public.customer_category_assignments where customer_id = (select id from _category_assignment_customer)), 2, 'update con categoria NULL conserva asignaciones');
select pg_temp.update_test_customer((select id from _category_assignment_customer), p_category_ids := '{}'::uuid[]);
select is((select count(*)::integer from public.customer_category_assignments where customer_id = (select id from _category_assignment_customer)), 0, 'update con array vacio elimina todas las asignaciones');
select pg_temp.update_test_customer((select id from _category_assignment_customer), p_category_ids := array[(select id from _category_fixture), (select id from _category_second)]);
select is((select count(*)::integer from public.customer_category_assignments where customer_id = (select id from _category_assignment_customer)), 2, 'update reemplaza el conjunto de categorias');
select public.update_customer_category((select id from _category_second), 'Categoria Secundaria', null, null, false);
select pg_temp.update_test_customer((select id from _category_assignment_customer), p_category_ids := array[(select id from _category_fixture), (select id from _category_second)]);
select is((select count(*)::integer from public.customer_category_assignments where customer_id = (select id from _category_assignment_customer)), 1, 'update ignora categoria inactiva');

insert into public.customer_category_assignments (customer_id, category_id)
values ((select id from _customer_fixture), (select id from _category_fixture));
select throws_ok($$select public.delete_customer_category((select id from _category_fixture))$$, 'P0001', 'CATEGORY_IN_USE', 'delete categoria asignada devuelve CATEGORY_IN_USE');
select is((select count(*)::integer from public.customer_categories where id = (select id from _category_fixture)), 1, 'delete fallido conserva categoria usada');
select is((select count(*)::integer from public.customer_category_assignments where category_id = (select id from _category_fixture) and customer_id = (select id from _customer_fixture)), 1, 'delete fallido conserva asignacion original');
delete from public.customer_category_assignments where category_id = (select id from _category_fixture);
select is(public.delete_customer_category((select id from _category_fixture)), true, 'delete elimina categoria sin asignaciones');
select is((select count(*)::integer from public.customer_categories where id = (select id from _category_fixture)), 0, 'categoria eliminada ya no existe');

select * from finish();
rollback;
