begin;

select plan(25);

-- Auditoria y operaciones de logo: inmutabilidad y endurecimiento.
--
-- Estas pruebas describen el estado deseado. Antes del endurecimiento FALLAN.
--
-- Huecos que cierran (verificado con `set local role authenticated` dentro de
-- rollback, 2026-10-03):
--   * `TRUNCATE` sobre `audit_logs` borraba el historial de auditoria
--     completo. La auditoria es `append-only` por
--     `architecture/module-security-contract.md` §8, pero RLS no aplica a
--     TRUNCATE y la tabla no tenia trigger que lo frenara. `audit_logs`
--     ademas concedia INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES y TRIGGER.
--   * `audit_actions` y `catalog_logo_operations` tenian politica RLS `ALL`.
--     No concedian privilegio de escritura, asi que hoy no eran explotables,
--     pero dependian de una sola capa.
--
-- Descartado tras verificarlo: `write_audit_log` **no** permite falsificar
-- auditoria. Es una funcion de `trigger` (retorno `trigger`), invocable solo
-- desde un trigger; llamarla directamente da
-- `trigger functions can only be called as triggers`.

-- ---------------------------------------------------------------------------
-- A. Capa de privilegios sobre el historial de auditoria
-- ---------------------------------------------------------------------------

select ok(
  not has_table_privilege('anon', 'public.audit_logs', 'INSERT'),
  'anon no inserta acciones de auditoria'
);
select ok(
  not has_table_privilege('anon', 'public.audit_logs', 'UPDATE'),
  'anon no modifica acciones de auditoria'
);
select ok(
  not has_table_privilege('anon', 'public.audit_logs', 'DELETE'),
  'anon no borra acciones de auditoria'
);
select ok(
  not has_table_privilege('anon', 'public.audit_logs', 'TRUNCATE'),
  'anon no vacia el historial de auditoria'
);
select ok(
  not has_table_privilege('authenticated', 'public.audit_logs', 'INSERT'),
  'authenticated no inserta acciones de auditoria'
);
select ok(
  not has_table_privilege('authenticated', 'public.audit_logs', 'UPDATE'),
  'authenticated no modifica acciones de auditoria'
);
select ok(
  not has_table_privilege('authenticated', 'public.audit_logs', 'DELETE'),
  'authenticated no borra acciones de auditoria'
);
select ok(
  not has_table_privilege('authenticated', 'public.audit_logs', 'TRUNCATE'),
  'authenticated no vacia el historial de auditoria'
);
select ok(
  has_table_privilege('authenticated', 'public.audit_logs', 'SELECT'),
  'authenticated conserva lectura del historial de auditoria'
);

-- ---------------------------------------------------------------------------
-- B. TRUNCATE bloqueado sobre el resto de registros
-- ---------------------------------------------------------------------------

select ok(
  not has_table_privilege('anon', 'public.audit_actions', 'TRUNCATE'),
  'anon no vacia audit_actions'
);
select ok(
  not has_table_privilege('authenticated', 'public.audit_actions', 'TRUNCATE'),
  'authenticated no vacia audit_actions'
);
select ok(
  not has_table_privilege('anon', 'public.catalog_logo_operations', 'TRUNCATE'),
  'anon no vacia catalog_logo_operations'
);
select ok(
  not has_table_privilege('authenticated', 'public.catalog_logo_operations', 'TRUNCATE'),
  'authenticated no vacia catalog_logo_operations'
);

-- ---------------------------------------------------------------------------
-- C. Capa de RLS
-- ---------------------------------------------------------------------------

select is(
  (select count(*) filter (where cmd <> 'SELECT')::integer from pg_policies
   where schemaname = 'public' and tablename = 'audit_logs'),
  0,
  'audit_logs no tiene politica de escritura'
);
select is(
  (select count(*) filter (where cmd <> 'SELECT')::integer from pg_policies
   where schemaname = 'public' and tablename = 'audit_actions'),
  0,
  'audit_actions no tiene politica de escritura'
);
select is(
  (select count(*) filter (where cmd <> 'SELECT')::integer from pg_policies
   where schemaname = 'public' and tablename = 'catalog_logo_operations'),
  0,
  'catalog_logo_operations no tiene politica de escritura'
);

-- ---------------------------------------------------------------------------
-- D. Comportamiento real con el rol de la aplicacion
-- ---------------------------------------------------------------------------

set local role authenticated;

select throws_ok(
  $$insert into public.audit_logs
      (table_name, record_id, operation, device_name, device_identifier)
    values ('x', extensions.gen_random_uuid(), 'UPDATE', 't', 't')$$,
  '42501',
  null,
  'authenticated no puede insertar una accion de auditoria'
);

select throws_ok(
  $$truncate public.audit_logs$$,
  '42501',
  null,
  'authenticated no puede vaciar el historial de auditoria'
);

select throws_ok(
  $$truncate public.audit_actions$$,
  '42501',
  null,
  'authenticated no puede vaciar audit_actions'
);

select throws_ok(
  $$truncate public.catalog_logo_operations$$,
  '42501',
  null,
  'authenticated no puede vaciar catalog_logo_operations'
);

reset role;

-- ---------------------------------------------------------------------------
-- E. Sin regresiones
-- ---------------------------------------------------------------------------

select ok(
  not has_function_privilege('authenticated', (select p.oid from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'audit_configuration_sales'), 'EXECUTE'),
  'audit_configuration_sales sigue siendo interna'
);
select ok(
  not has_function_privilege('authenticated', (select p.oid from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'audit_payments'), 'EXECUTE'),
  'audit_payments sigue siendo interna'
);
select is(
  (select pg_get_function_result(p.oid) from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'write_audit_log'),
  'trigger',
  'write_audit_log sigue siendo funcion de trigger, no invocable'
);
select ok(
  has_function_privilege('authenticated', (select p.oid from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'register_catalog_logo_version'), 'EXECUTE'),
  'la app sigue pudiendo registrar versiones de logo'
);
select ok(
  not has_table_privilege('authenticated', 'public.audit_actions', 'SELECT'),
  'audit_actions es interna: sin acceso directo para clientes'
);

select * from finish();
rollback;
