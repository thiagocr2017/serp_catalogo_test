-- Políticas de lectura para tablas de negocio sin cobertura RLS
--
-- Todas estas tablas tienen RLS activado pero ninguna política, por lo
-- que la app (rol anon vía publishable key) recibía listas vacías aunque
-- las escrituras vía RPC funcionaran. Se añade la misma política de
-- lectura local que ya usan categories/products: acceso total de lectura
-- para anon y authenticated con USING (true).
--
-- Las escrituras directas siguen bloqueadas: los GRANT de tabla están
-- revocados y estas políticas no definen WITH CHECK, así que toda
-- mutación pasa únicamente por las RPC SECURITY DEFINER.

drop policy if exists audit_actions_local_access on public.audit_actions;
create policy audit_actions_local_access on public.audit_actions
  for all to anon, authenticated using (true);

drop policy if exists catalog_logo_operations_local_access on public.catalog_logo_operations;
create policy catalog_logo_operations_local_access on public.catalog_logo_operations
  for all to anon, authenticated using (true);

drop policy if exists customer_credit_entries_local_access on public.customer_credit_entries;
create policy customer_credit_entries_local_access on public.customer_credit_entries
  for all to anon, authenticated using (true);

drop policy if exists customers_local_access on public.customers;
create policy customers_local_access on public.customers
  for all to anon, authenticated using (true);

drop policy if exists expenses_local_access on public.expenses;
create policy expenses_local_access on public.expenses
  for all to anon, authenticated using (true);

drop policy if exists inventory_count_lines_local_access on public.inventory_count_lines;
create policy inventory_count_lines_local_access on public.inventory_count_lines
  for all to anon, authenticated using (true);

drop policy if exists inventory_counts_local_access on public.inventory_counts;
create policy inventory_counts_local_access on public.inventory_counts
  for all to anon, authenticated using (true);

drop policy if exists inventory_reservations_local_access on public.inventory_reservations;
create policy inventory_reservations_local_access on public.inventory_reservations
  for all to anon, authenticated using (true);

drop policy if exists money_account_transactions_local_access on public.money_account_transactions;
create policy money_account_transactions_local_access on public.money_account_transactions
  for all to anon, authenticated using (true);

drop policy if exists money_accounts_local_access on public.money_accounts;
create policy money_accounts_local_access on public.money_accounts
  for all to anon, authenticated using (true);

drop policy if exists packaging_presentation_create_commands_local_access on public.packaging_presentation_create_commands;
create policy packaging_presentation_create_commands_local_access on public.packaging_presentation_create_commands
  for all to anon, authenticated using (true);

drop policy if exists payment_applications_local_access on public.payment_applications;
create policy payment_applications_local_access on public.payment_applications
  for all to anon, authenticated using (true);

drop policy if exists payment_commands_local_access on public.payment_commands;
create policy payment_commands_local_access on public.payment_commands
  for all to anon, authenticated using (true);

drop policy if exists payment_components_local_access on public.payment_components;
create policy payment_components_local_access on public.payment_components
  for all to anon, authenticated using (true);

drop policy if exists payment_methods_local_access on public.payment_methods;
create policy payment_methods_local_access on public.payment_methods
  for all to anon, authenticated using (true);

drop policy if exists payments_local_access on public.payments;
create policy payments_local_access on public.payments
  for all to anon, authenticated using (true);

drop policy if exists refund_commands_local_access on public.refund_commands;
create policy refund_commands_local_access on public.refund_commands
  for all to anon, authenticated using (true);

drop policy if exists refunds_local_access on public.refunds;
create policy refunds_local_access on public.refunds
  for all to anon, authenticated using (true);

drop policy if exists sales_agent_create_commands_local_access on public.sales_agent_create_commands;
create policy sales_agent_create_commands_local_access on public.sales_agent_create_commands
  for all to anon, authenticated using (true);

drop policy if exists sales_consignment_lines_local_access on public.sales_consignment_lines;
create policy sales_consignment_lines_local_access on public.sales_consignment_lines
  for all to anon, authenticated using (true);

drop policy if exists sales_consignments_local_access on public.sales_consignments;
create policy sales_consignments_local_access on public.sales_consignments
  for all to anon, authenticated using (true);

drop policy if exists sales_invoice_commands_local_access on public.sales_invoice_commands;
create policy sales_invoice_commands_local_access on public.sales_invoice_commands
  for all to anon, authenticated using (true);

drop policy if exists sales_invoice_lines_local_access on public.sales_invoice_lines;
create policy sales_invoice_lines_local_access on public.sales_invoice_lines
  for all to anon, authenticated using (true);

drop policy if exists sales_invoices_local_access on public.sales_invoices;
create policy sales_invoices_local_access on public.sales_invoices
  for all to anon, authenticated using (true);

drop policy if exists sales_order_lines_local_access on public.sales_order_lines;
create policy sales_order_lines_local_access on public.sales_order_lines
  for all to anon, authenticated using (true);

drop policy if exists sales_orders_local_access on public.sales_orders;
create policy sales_orders_local_access on public.sales_orders
  for all to anon, authenticated using (true);

drop policy if exists sales_quote_lines_local_access on public.sales_quote_lines;
create policy sales_quote_lines_local_access on public.sales_quote_lines
  for all to anon, authenticated using (true);

drop policy if exists sales_quotes_local_access on public.sales_quotes;
create policy sales_quotes_local_access on public.sales_quotes
  for all to anon, authenticated using (true);

drop policy if exists sales_return_lines_local_access on public.sales_return_lines;
create policy sales_return_lines_local_access on public.sales_return_lines
  for all to anon, authenticated using (true);

drop policy if exists sales_returns_local_access on public.sales_returns;
create policy sales_returns_local_access on public.sales_returns
  for all to anon, authenticated using (true);

drop policy if exists unidentified_deposits_local_access on public.unidentified_deposits;
create policy unidentified_deposits_local_access on public.unidentified_deposits
  for all to anon, authenticated using (true);
