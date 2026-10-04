-- Endurecer la auditoria y las operaciones de logo.
--
-- `.specs/architecture/module-security-contract.md` §8 dice que la auditoria
-- es `append-only` para roles ordinarios. No lo era.
--
-- Antes de esta migracion:
--
--   * `audit_logs` concedia a `anon` y `authenticated` INSERT, UPDATE, DELETE,
--     TRUNCATE, REFERENCES y TRIGGER. `INSERT`, `UPDATE` y `DELETE` los salvaba
--     RLS (solo hay politica de `SELECT`), pero **`TRUNCATE` si funcionaba**:
--     RLS no aplica a operaciones que no son por fila y la tabla no tenia
--     trigger que lo frenara. El historial de auditoria se podia vaciar de un
--     solo golpe.
--   * `audit_actions` y `catalog_logo_operations` tenian politica RLS `ALL`.
--     No concedian privilegio de escritura, asi que no eran explotables, pero
--     dependian de una sola capa: un `GRANT` futuro las habria abierto.
--
-- Descartado tras verificarlo: `write_audit_log` **no** permite falsificar
-- auditoria. Es una funcion de `trigger` (retorno `trigger`), invocable solo
-- desde un trigger.
--
-- Las escrituras legitimas pasan por RPC `SECURITY DEFINER` de `postgres`
-- (`audit_configuration_sales`, `audit_payments`, `write_audit_log`,
-- `register_catalog_logo_version`, `delete_category_and_reassign_products`,
-- `purge_test_data_and_go_production`), que corren como propietario y no
-- necesitan estos privilegios. `register_catalog_logo_version` y
-- `purge_test_data_and_go_production` se conservan ejecutables porque la
-- aplicacion los invoca.

-- 1. El historial de auditoria es append-only: solo lectura para clientes.
revoke insert, update, delete, truncate, references, trigger
  on table public.audit_logs
  from anon, authenticated;
grant select on table public.audit_logs to anon, authenticated;

-- 2. `audit_actions` y `catalog_logo_operations` son internas: sin acceso
--    directo para clientes. Se estrecha la politica para que un futuro `GRANT`
--    no las abra por accidente. `using (false)` deja la intencion explicita en
--    el esquema, que es mas legible que no tener politica alguna.
drop policy if exists audit_actions_local_access on public.audit_actions;
drop policy if exists audit_actions_local_read on public.audit_actions;
drop policy if exists audit_actions_sealed on public.audit_actions;
create policy audit_actions_sealed on public.audit_actions
  for select
  to anon, authenticated
  using (false);

drop policy if exists catalog_logo_operations_local_access
  on public.catalog_logo_operations;
drop policy if exists catalog_logo_operations_local_read
  on public.catalog_logo_operations;
drop policy if exists catalog_logo_operations_sealed
  on public.catalog_logo_operations;
create policy catalog_logo_operations_sealed on public.catalog_logo_operations
  for select
  to anon, authenticated
  using (false);

revoke insert, update, delete, truncate, references, trigger
  on table public.audit_actions
  from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger
  on table public.catalog_logo_operations
  from anon, authenticated;

-- 3. Blindar el TRUNCATE con triggers de tabla. Los triggers `BEFORE DELETE`
--    no interceptan TRUNCATE, asi que sin esto la inmutabilidad descansaria
--    sobre un solo `GRANT`. Reutiliza la funcion creada para el libro de
--    inventario.
drop trigger if exists audit_logs_no_truncate on public.audit_logs;
create trigger audit_logs_no_truncate
  before truncate on public.audit_logs
  for each statement
  execute function public.prevent_inventory_transaction_truncate();

drop trigger if exists audit_actions_no_truncate on public.audit_actions;
create trigger audit_actions_no_truncate
  before truncate on public.audit_actions
  for each statement
  execute function public.prevent_inventory_transaction_truncate();

drop trigger if exists catalog_logo_operations_no_truncate
  on public.catalog_logo_operations;
create trigger catalog_logo_operations_no_truncate
  before truncate on public.catalog_logo_operations
  for each statement
  execute function public.prevent_inventory_transaction_truncate();
