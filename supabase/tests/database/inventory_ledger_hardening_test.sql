begin;

select plan(20);

-- Inventario: endurecimiento del libro inmutable y de los saldos.
--
-- Estas pruebas describen el estado deseado. Antes del endurecimiento FALLAN,
-- que es exactamente su funcion: detectar que falta el endurecimiento.
--
-- Hueco que cierran (verificado con `set local role authenticated` dentro de
-- rollback, 2026-10-03):
--   * `INSERT` directo sobre `inventory_transactions` creaba movimientos sin
--     documento de inventario y el trigger `apply_inventory_transaction()`
--     aplicaba el stock. Esquivaba todo el flujo documental.
--   * `TRUNCATE` sobre `inventory_transactions` borraba el libro inmutable
--     completo. RLS no aplica a TRUNCATE y el trigger `BEFORE DELETE` tampoco
--     lo frena.
--   * `TRUNCATE` sobre `inventory_balances` borraba todos los saldos fisicos.
-- `UPDATE` y `DELETE` ya quedaban fuera por RLS (0 filas).

-- ---------------------------------------------------------------------------
-- A. Capa de privilegios
-- ---------------------------------------------------------------------------

select ok(
  not has_table_privilege('anon', 'public.inventory_transactions', 'INSERT'),
  'anon no inserta movimientos'
);
select ok(
  not has_table_privilege('anon', 'public.inventory_transactions', 'UPDATE'),
  'anon no actualiza movimientos'
);
select ok(
  not has_table_privilege('anon', 'public.inventory_transactions', 'DELETE'),
  'anon no borra movimientos'
);
select ok(
  not has_table_privilege('anon', 'public.inventory_transactions', 'TRUNCATE'),
  'anon no vacia el libro de movimientos'
);
select ok(
  not has_table_privilege('authenticated', 'public.inventory_transactions', 'INSERT'),
  'authenticated no inserta movimientos'
);
select ok(
  not has_table_privilege('authenticated', 'public.inventory_transactions', 'UPDATE'),
  'authenticated no actualiza movimientos'
);
select ok(
  not has_table_privilege('authenticated', 'public.inventory_transactions', 'DELETE'),
  'authenticated no borra movimientos'
);
select ok(
  not has_table_privilege('authenticated', 'public.inventory_transactions', 'TRUNCATE'),
  'authenticated no vacia el libro de movimientos'
);
select ok(
  not has_table_privilege('anon', 'public.inventory_balances', 'TRUNCATE'),
  'anon no vacia los saldos'
);
select ok(
  not has_table_privilege('authenticated', 'public.inventory_balances', 'TRUNCATE'),
  'authenticated no vacia los saldos'
);
select ok(
  has_table_privilege('authenticated', 'public.inventory_transactions', 'SELECT'),
  'authenticated conserva lectura de movimientos'
);
select ok(
  has_table_privilege('authenticated', 'public.inventory_balances', 'SELECT'),
  'authenticated conserva lectura de saldos'
);

-- ---------------------------------------------------------------------------
-- B. Capa de RLS
-- ---------------------------------------------------------------------------

select is(
  (select count(*)::integer from pg_policies
   where schemaname = 'public'
     and tablename = 'inventory_transactions'),
  1,
  'inventory_transactions tiene una sola politica'
);
select is(
  (select count(*) filter (where cmd <> 'SELECT')::integer from pg_policies
   where schemaname = 'public'
     and tablename = 'inventory_transactions'),
  0,
  'inventory_transactions no tiene politica de escritura'
);
select is(
  (select count(*) filter (where cmd <> 'SELECT')::integer from pg_policies
   where schemaname = 'public'
     and tablename = 'inventory_balances'),
  0,
  'inventory_balances no tiene politica de escritura'
);

-- ---------------------------------------------------------------------------
-- C. Comportamiento real con el rol de la aplicacion
-- ---------------------------------------------------------------------------

set local role authenticated;

select throws_ok(
  $$insert into public.inventory_transactions
      (product_id, warehouse_id, location_id, command_id, quantity, reason,
       notes, actor_name, device_name, device_identifier)
    select p.id, w.id, l.id, extensions.gen_random_uuid(), 1, 'ADJUSTMENT',
           'prueba de endurecimiento', 'prueba', 'prueba', 'prueba'
      from public.products p, public.warehouses w, public.inventory_locations l
     limit 1$$,
  '42501',
  null,
  'authenticated no puede insertar un movimiento directo'
);

select throws_ok(
  $$truncate public.inventory_transactions$$,
  '42501',
  null,
  'authenticated no puede vaciar el libro de movimientos'
);

select throws_ok(
  $$truncate public.inventory_balances$$,
  '42501',
  null,
  'authenticated no puede vaciar los saldos'
);

reset role;

-- ---------------------------------------------------------------------------
-- D. Sin regresiones
-- ---------------------------------------------------------------------------

select ok(
  exists(
    select 1 from pg_trigger
     where tgrelid = 'public.inventory_transactions'::regclass
       and tgname = 'inventory_transactions_no_update_or_delete'
  ),
  'el trigger de inmutabilidad sigue presente'
);
select ok(
  has_function_privilege(
    'authenticated',
    (select p.oid from pg_proc p
       join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = 'create_and_confirm_inventory_document'),
    'EXECUTE'
  ),
  'el camino documental sigue disponible para authenticated'
);

select * from finish();
rollback;
