begin;
select plan(20);

-- Catalogo de tipos de identificacion
select has_table('public','identification_types','existe identification_types');
select has_column('public','identification_types','code','tiene code');
select has_column('public','identification_types','name','tiene name');
select has_column('public','identification_types','is_active','tiene is_active');

select is(
  (select count(*)::integer from public.identification_types where is_active),
  6,
  'hay 6 tipos de identificacion activos precargados'
);

select results_eq(
  $$select code, name from public.identification_types order by code$$,
  $$values
    ('DIMEX','DIMEX'),
    ('FOREIGN_ID','Extranjero'),
    ('JURIDICAL_ID','Cédula jurídica'),
    ('NITE','NITE'),
    ('PASSPORT','Pasaporte'),
    ('PHYSICAL_ID','Cédula física')
  $$,
  'los 6 codigos y nombres son los esperados'
);

select ok(
  has_table_privilege('authenticated','public.identification_types','SELECT'),
  'authenticated puede leer identification_types'
);
select ok(
  not has_table_privilege('authenticated','public.identification_types','INSERT'),
  'authenticated no puede insertar identification_types'
);

-- Campos fiscales en customers
select has_column('public','customers','identification_type_id','customers tiene identification_type_id');
select has_column('public','customers','economic_activity','customers tiene economic_activity');

-- Crear cliente con datos fiscales
select is(
  (public.create_customer(
    'Cliente Fiscal', null, null, null, null, '123456789',
    null, null, null, null::uuid, 'CASH', null, 'E_INVOICE',
    false::boolean,
    (select id from public.identification_types where code = 'JURIDICAL_ID'),
    'Venta al por mayor',
    'actor','device','device'
  )).tax_id,
  '123456789',
  'crea cliente con tax_id'
);

select is(
  (select economic_activity from public.customers where name = 'Cliente Fiscal'),
  'Venta al por mayor',
  'guarda actividad economica'
);

select is(
  (select identification_type_id from public.customers where name = 'Cliente Fiscal'),
  (select id from public.identification_types where code = 'JURIDICAL_ID'),
  'guarda tipo de identificacion'
);

-- Actualizar cliente cambiando tipo de identificacion
select is(
  (public.update_customer(
    (select id from public.customers where name = 'Cliente Fiscal'),
    'Cliente Fiscal'::text, null::text, null::text, null::text, null::text, '123456789'::text,
    null::numeric, null::text, null::text, null::uuid, 'CASH'::text, null::int, 'E_INVOICE'::text,
    false::boolean,
    (select id from public.identification_types where code = 'PHYSICAL_ID'),
    'Venta al por menor'::text,
    'actor'::text,'device'::text,'device'::text
  )).economic_activity,
  'Venta al por menor',
  'actualiza actividad economica'
);

-- Tipo de identificacion inactivo o inexistente debe fallar
select throws_ok(
  $$select public.create_customer(
    'Cliente Mal', null, null, null, null, '0',
    null, null, null, null::uuid, 'CASH', null, 'E_INVOICE',
    false::boolean,
    '00000000-0000-0000-0000-000000000000'::uuid,
    'Actividad',
    'actor','device','device'
  )$$,
  'P0001','IDENTIFICATION_TYPE_INACTIVE',
  'rechaza tipo de identificacion inexistente'
);

-- requires_e_invoice (decision 20): trigger de datos obligatorios
select has_column(
  'public','customers','requires_e_invoice',
  'customers tiene requires_e_invoice'
);

select is(
  (select requires_e_invoice from public.customers where name = 'Cliente Fiscal'),
  false,
  'requires_e_invoice es false por defecto'
);

select is(
  (public.create_customer(
    'Cliente FE', null, null, 'fe@example.com', 'Av. Central 1', '333444555',
    null, null, null, null::uuid, 'CASH', null, 'E_INVOICE',
    true::boolean,
    (select id from public.identification_types where code = 'NITE'),
    'Servicios',
    'actor','device','device'
  )).requires_e_invoice,
  true,
  'crea cliente con factura electronica y todos los datos obligatorios'
);

select throws_ok(
  $$select public.create_customer(
    'Cliente FE Incompleto', null, null, null, null, null,
    null, null, null, null::uuid, 'CASH', null, 'E_INVOICE',
    true::boolean,
    null::uuid,
    'Servicios',
    'actor','device','device'
  )$$,
  'P0001','E_INVOICE_TAX_ID_REQUIRED',
  'factura electronica exige numero de identificacion'
);

select throws_ok(
  $$select public.create_customer(
    'Cliente FE Sin Direccion', null, null, 'fe2@example.com', null, '111222333',
    null, null, null, null::uuid, 'CASH', null, 'E_INVOICE',
    true::boolean,
    (select id from public.identification_types where code = 'NITE'),
    'Servicios',
    'actor','device','device'
  )$$,
  'P0001','E_INVOICE_ADDRESS_REQUIRED',
  'factura electronica exige direccion'
);

select * from finish();
rollback;
