-- Endurecer el libro inmutable de inventario y sus saldos.
--
-- Antes de esta migracion, cualquier cliente local (roles `anon` y
-- `authenticated`) podia:
--
--   * INSERTAR movimientos directamente en `inventory_transactions`, sin
--     documento de inventario, y el trigger `apply_inventory_transaction()`
--     aplicaba el stock. Esquivaba todo el flujo documental.
--   * TRUNCATE `inventory_transactions` y borrar el libro inmutable completo.
--     RLS no aplica a TRUNCATE y el trigger `BEFORE DELETE`
--     `inventory_transactions_no_update_or_delete` no lo frena.
--   * TRUNCATE `inventory_balances` y borrar todos los saldos fisicos.
--
-- `UPDATE` y `DELETE` sobre `inventory_transactions` ya quedaban fuera por RLS
-- (sin politica de escritura, se afectan 0 filas), pero el privilegio seguia
-- concedido y era un solo `DROP POLICY` de distancia.
--
-- Las escrituras legitimas pasan por RPC `SECURITY DEFINER`
-- (`create_and_confirm_inventory_document`, `confirm_inventory_document`,
-- `record_inventory_transaction`, `reverse_inventory_transaction`, etc.), que
-- corren como propietario y no necesitan estos privilegios. Verificado antes de
-- aplicar el cambio.
--
-- Regla de `.specs/architecture/module-security-contract.md` §8: los movimientos contables o de
-- inventario no se editan ni se eliminan fisicamente.

-- 1. Revocar todo privilegio de escritura sobre el libro inmutable.
revoke insert, update, delete, truncate, references, trigger
  on table public.inventory_transactions
  from anon, authenticated;

-- 2. Revocar privilegios innecesarios sobre los saldos fisicos. Solo lectura.
revoke insert, update, delete, truncate, references, trigger
  on table public.inventory_balances
  from anon, authenticated;

grant select on table public.inventory_transactions to anon, authenticated;
grant select on table public.inventory_balances to anon, authenticated;

-- 3. Retirar la politica de insercion de RLS. Con ella viva, cualquier cliente
--    que consiguiera el privilegio volveria a poder insertar movimientos.
drop policy if exists inventory_local_insert on public.inventory_transactions;

-- 4. Unica politica que debe quedar sobre el libro: lectura.
drop policy if exists inventory_local_read on public.inventory_transactions;
create policy inventory_local_read on public.inventory_transactions
  for select
  to anon, authenticated
  using (true);

-- 5. Blindar el TRUNCATE del libro con un trigger a nivel de tabla. Los
--    triggers `BEFORE DELETE` no interceptan TRUNCATE, asi que sin esto la
--    inmutabilidad depende solo del privilegio.
create or replace function public.prevent_inventory_transaction_truncate()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = 'INVENTORY_LEDGER_IMMUTABLE';
end;
$$;

drop trigger if exists inventory_transactions_no_truncate
  on public.inventory_transactions;
create trigger inventory_transactions_no_truncate
  before truncate on public.inventory_transactions
  for each statement
  execute function public.prevent_inventory_transaction_truncate();

drop trigger if exists inventory_balances_no_truncate
  on public.inventory_balances;
create trigger inventory_balances_no_truncate
  before truncate on public.inventory_balances
  for each statement
  execute function public.prevent_inventory_transaction_truncate();

revoke execute on function public.prevent_inventory_transaction_truncate()
  from anon, authenticated;
