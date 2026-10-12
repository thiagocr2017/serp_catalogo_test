begin;
select plan(27);

-- Contrato de las RPC de gestion (decision 23)
select has_table(
  'public','identification_type_create_commands',
  'existe la tabla de comandos idempotentes'
);
select has_function(
  'public',
  'create_identification_type',
  '{uuid,text,text,text,text,text}'::text[],
  'existe create_identification_type con su firma'
);
select has_function(
  'public',
  'update_identification_type',
  '{uuid,text,boolean,integer,text,text,text}'::text[],
  'existe update_identification_type con su firma'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.create_identification_type(uuid,text,text,text,text,text)'::regprocedure,
    'EXECUTE'
  ),
  'authenticated ejecuta create_identification_type'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.update_identification_type(uuid,text,boolean,integer,text,text,text)'::regprocedure,
    'EXECUTE'
  ),
  'authenticated ejecuta update_identification_type'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.identification_type_create_commands',
    'INSERT'
  ),
  'authenticated no escribe la tabla de comandos'
);
select ok(
  (select relrowsecurity
     from pg_class
    where oid = 'public.identification_type_create_commands'::regclass),
  'RLS esta habilitado en la tabla interna de comandos'
);
select ok(
  not has_table_privilege(
    'anon', 'public.identification_type_create_commands', 'SELECT,INSERT,UPDATE,DELETE'
  ),
  'anon no tiene acceso directo a la tabla de comandos'
);
select ok(
  not has_table_privilege(
    'authenticated', 'public.identification_type_create_commands', 'SELECT,INSERT,UPDATE,DELETE'
  ),
  'authenticated no tiene acceso directo a la tabla de comandos'
);
select is(
  (select count(*)::integer
     from pg_policy
    where polrelid = 'public.identification_type_create_commands'::regclass),
  0,
  'la tabla interna no tiene politicas de acceso cliente'
);

-- Alta
select is(
  (public.create_identification_type(
    '11111111-1111-1111-1111-111111111111'::uuid,
    'TEST_TYPE', 'Tipo de prueba',
    'actor'::text, 'device'::text, 'device'::text
  )).name,
  'Tipo de prueba',
  'crea el tipo con el nombre dado'
);

select is(
  (select version from public.identification_types where code = 'TEST_TYPE'),
  1,
  'el tipo nuevo nace en version 1'
);

-- Idempotencia: el mismo command_id con el mismo payload no duplica
select is(
  (public.create_identification_type(
    '11111111-1111-1111-1111-111111111111'::uuid,
    'TEST_TYPE', 'Tipo de prueba',
    'actor'::text, 'device'::text, 'device'::text
  )).id,
  (select id from public.identification_types where code = 'TEST_TYPE'),
  'repetir el comando devuelve la misma fila'
);

select is(
  (select count(*)::integer from public.identification_types where code = 'TEST_TYPE'),
  1,
  'la repeticion no duplico el tipo'
);

select throws_ok(
  $$select public.create_identification_type(
    '11111111-1111-1111-1111-111111111111'::uuid,
    'TEST_TYPE', 'Otro nombre',
    'actor','device','device'
  )$$,
  'P0001','COMMAND_PAYLOAD_MISMATCH',
  'reutilizar el command_id con otro payload se rechaza'
);

select throws_ok(
  $$select public.create_identification_type(
    '22222222-2222-2222-2222-222222222222'::uuid,
    'TEST_TYPE', 'Otro nombre',
    'actor','device','device'
  )$$,
  'P0001','DUPLICATE_IDENTIFICATION_TYPE_CODE',
  'otro comando con el mismo codigo se rechaza'
);

select throws_ok(
  $$select public.create_identification_type(
    '33333333-3333-3333-3333-333333333333'::uuid,
    'SIN_NOMBRE', '   ',
    'actor','device','device'
  )$$,
  'P0001','INVALID_INPUT',
  'rechaza nombre vacio'
);

-- Edicion
select is(
  (public.update_identification_type(
    (select id from public.identification_types where code = 'TEST_TYPE'),
    'Tipo renombrado', true, 1,
    'actor'::text, 'device'::text, 'device'::text
  )).name,
  'Tipo renombrado',
  'renombra el tipo'
);

select is(
  (select version from public.identification_types where code = 'TEST_TYPE'),
  2,
  'la edicion sube la version'
);

select throws_ok(
  $$select public.update_identification_type(
    (select id from public.identification_types where code = 'TEST_TYPE'),
    'Version vieja', true, 1,
    'actor','device','device'
  )$$,
  'P0001','VERSION_CONFLICT',
  'editar con una version vieja se rechaza'
);

select throws_ok(
  $$select public.update_identification_type(
    '00000000-0000-0000-0000-000000000000'::uuid,
    'Inexistente', true, 1,
    'actor','device','device'
  )$$,
  'P0001','NOT_FOUND',
  'editar un tipo inexistente se rechaza'
);

-- Desactivacion y su efecto en clientes
select is(
  (public.update_identification_type(
    (select id from public.identification_types where code = 'TEST_TYPE'),
    'Tipo renombrado', false, 2,
    'actor'::text, 'device'::text, 'device'::text
  )).is_active,
  false,
  'desactiva el tipo'
);

select throws_ok(
  $$select public.create_customer(
    'Cliente Tipo Inactivo', 'Fantasia Inactivo', '88887777', null, 'San José', '0',
    null, 'CR', 'San José', null, 'Gira Central', null::uuid, 'CASH', null, 'E_INVOICE',
    false::boolean,
    (select id from public.identification_types where code = 'TEST_TYPE'),
    'Actividad',
    'actor','device','device'
  )$$,
  'P0001','IDENTIFICATION_TYPE_INACTIVE',
  'un tipo desactivado no se puede asignar a un cliente'
);

-- Auditoria
select ok(
  exists(
    select 1 from public.audit_actions
     where entity_type = 'identification_types'
       and operation = 'CREATE'
  ),
  'auditoria del alta'
);
select ok(
  exists(
    select 1 from public.audit_logs
     where table_name = 'identification_types'
       and field_name = 'name'
       and new_value = 'Tipo renombrado'
  ),
  'auditoria del renombre'
);
select ok(
  exists(
    select 1 from public.audit_actions
     where entity_type = 'identification_types'
       and operation = 'DEACTIVATE'
  ),
  'auditoria de la desactivacion'
);

-- Los 6 tipos precargados siguen intactos
select is(
  (select count(*)::integer from public.identification_types where is_active),
  6,
  'los 6 tipos precargados siguen activos'
);

select * from finish();
rollback;
