begin;
select plan(24);

-- Tabla y columna base
select has_table('public','customer_emails','existe la tabla customer_emails');
select has_column('public','customer_emails','purpose','tiene proposito');
select has_column('public','customer_emails','is_active','tiene estado activo');

-- Funciones publicas
select has_function(
  'public','create_customer_email',
  array['uuid','text','text','text','text','text','text']::name[],
  'existe create_customer_email'
);
select has_function(
  'public','update_customer_email',
  array['uuid','text','text','text','boolean','text','text','text']::name[],
  'existe update_customer_email'
);
select has_function(
  'public','delete_customer_email',
  array['uuid','text','text','text']::name[],
  'existe delete_customer_email'
);

-- Privilegios de ejecucion
select ok(has_function_privilege('anon','public.create_customer_email(uuid,text,text,text,text,text,text)'::regprocedure,'EXECUTE'),'anon ejecuta create_customer_email');
select ok(has_function_privilege('authenticated','public.create_customer_email(uuid,text,text,text,text,text,text)'::regprocedure,'EXECUTE'),'authenticated ejecuta create_customer_email');
select ok(has_function_privilege('authenticated','public.update_customer_email(uuid,text,text,text,boolean,text,text,text)'::regprocedure,'EXECUTE'),'authenticated ejecuta update_customer_email');
select ok(has_function_privilege('authenticated','public.delete_customer_email(uuid,text,text,text)'::regprocedure,'EXECUTE'),'authenticated ejecuta delete_customer_email');

-- Direct write debe estar revocado
select ok(
  not has_table_privilege('authenticated','public.customer_emails','INSERT'),
  'authenticated no puede insertar directamente'
);
select ok(
  not has_table_privilege('authenticated','public.customer_emails','UPDATE'),
  'authenticated no puede actualizar directamente'
);
select ok(
  not has_table_privilege('authenticated','public.customer_emails','DELETE'),
  'authenticated no puede borrar directamente'
);

-- Fixture: un cliente para los correos
select is(
  (public.create_customer(
    'pgTAP Customer', 'pgTAP Fantasia', '88881234', 'test@test.com', 'San José', null, 0,
    'CR', 'San José', null, 'Gira Norte', null::uuid, 'CASH', null, 'E_INVOICE',
    false::boolean, null::uuid, null,
    'actor','device','device'
  )).name,
  'pgTAP Customer',
  'cliente de prueba creado'
) as customer;

-- Escenario principal: crear primario y copia, luego cambiar copia a primario
with customer as (
  select id from public.customers where name = 'pgTAP Customer' limit 1
)
select lives_ok(
  $$with customer as (select id from public.customers where name = 'pgTAP Customer' limit 1)
    select public.create_customer_email(
      (select id from customer),
      'principal@example.com','PRIMARY','Facturacion',
      'actor','device','device'
    )$$,
  'crea correo principal'
);

select is(
  (select count(*)::integer from public.customer_emails where email = 'principal@example.com'),
  1,
  'correo principal insertado'
);

select lives_ok(
  $$with customer as (select id from public.customers where name = 'pgTAP Customer' limit 1)
    select public.create_customer_email(
      (select id from customer),
      'copia@example.com','COPY','Contabilidad',
      'actor','device','device'
    )$$,
  'crea correo en copia'
);

-- Segundo primario convierte al anterior en copia
select lives_ok(
  $$with customer as (select id from public.customers where name = 'pgTAP Customer' limit 1)
    select public.create_customer_email(
      (select id from customer),
      'nuevo@example.com','PRIMARY','Nuevo principal',
      'actor','device','device'
    )$$,
  'crear otro primario desplaza al anterior'
);

select is(
  (select count(*)::integer from public.customer_emails
    where customer_id = (select id from public.customers where name = 'pgTAP Customer' limit 1)
      and purpose = 'PRIMARY'),
  1,
  'solo hay un correo primario'
);

-- Validaciones
select throws_ok(
  $$with customer as (select id from public.customers where name = 'pgTAP Customer' limit 1)
    select public.create_customer_email(
      (select id from customer),'no-es-email','COPY','',
      'actor','device','device'
    )$$,
  'P0001',
  'INVALID_EMAIL',
  'rechaza email invalido'
);

-- Actualizacion: la copia pasa a primaria
select is(
  (public.update_customer_email(
    (select id from public.customer_emails where email = 'copia@example.com'),
    'copia@example.com','PRIMARY','',true,
    'actor','device','device'
  )).purpose,
  'PRIMARY',
  'actualiza copia a primaria'
);

-- Borrado
select lives_ok(
  $$select public.delete_customer_email(
    (select id from public.customer_emails where email = 'principal@example.com'),
    'actor','device','device'
  )$$,
  'borra correo'
);

select is(
  (select count(*)::integer from public.customer_emails where email = 'principal@example.com'),
  0,
  'correo borrado desaparece'
);

-- Borrar inexistente
select throws_ok(
  $$select public.delete_customer_email('00000000-0000-0000-0000-000000000000','actor','device','device')$$,
  'P0001','NOT_FOUND',
  'borrar inexistente lanza NOT_FOUND'
);

select * from finish();
rollback;
