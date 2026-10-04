# Esquema de base de datos

Este documento resume el estado real de la base local consultada desde
PostgreSQL/Supabase.

## Regla de permisos

La regla es que la app escriba mediante RPCs `security definer` y que los roles
`anon` y `authenticated` no hagan `insert`, `update` ni `delete` directo sobre
las tablas protegidas.

Ejemplo confirmado:

- `customer_contacts` concede `SELECT` a `anon` y `authenticated`.
- Un `POST /rest/v1/customer_contacts` falla con `permission denied for table customer_contacts`.
- `POST /rest/v1/rpc/create_customer_contact` funciona y genera UUID real.

### Excepciones verificadas (2026-10-03)

La regla **no** se cumplia en todos los objetos. Comprobado con
`set local role authenticated` dentro de `rollback`:

| Objeto | Situacion | Prueba |
|---|---|---|
| ~~`inventory_transactions`~~ | **Cerrado el 2026-10-03** por `20261003100000_harden_inventory_ledger.sql`. Aceptaba `INSERT` directo y `TRUNCATE` | Ver abajo |
| `audit_logs` | Concede `INSERT,UPDATE,DELETE,TRUNCATE`, pero su unica politica RLS es de `SELECT` | `new row violates row-level security policy` |
| `inventory_balances` | **Cerrado el 2026-10-03**: concedia `TRUNCATE,REFERENCES,TRIGGER` | `permission denied` tras el endurecimiento |
| `catalog_logo_operations` | Revisar privilegios | pendiente |

#### Hueco de `inventory_transactions`, cerrado

Antes del endurecimiento, cualquier cliente local podia:

- `INSERT` movimientos sin documento de inventario; el trigger
  `apply_inventory_transaction()` aplicaba el stock, esquivando todo el flujo
  documental;
- `TRUNCATE` el libro inmutable completo. **RLS no aplica a TRUNCATE** y el
  trigger `BEFORE DELETE` tampoco lo frena;
- `TRUNCATE` `inventory_balances` y borrar todos los saldos fisicos.

`UPDATE` y `DELETE` ya quedaban fuera por RLS, pero el privilegio seguia
concedido.

Cerrado con `20261003100000_harden_inventory_ledger.sql`: revoca escritura en
ambas tablas, retira la politica `inventory_local_insert`, deja solo lectura y
anade triggers `BEFORE TRUNCATE` porque los triggers `BEFORE DELETE` no cubren
TRUNCATE. Las escrituras legitimas pasan por RPC `SECURITY DEFINER`, que no
necesitan estos privilegios.

Verificado: los cinco vectores (`insert`, `update`, `delete`, `truncate` en el
libro y `truncate` en saldos) devuelven `permission denied`, y
`record_inventory_transaction` sigue funcionando. Las 20 pruebas de
`supabase/tests/database/inventory_ledger_hardening_test.sql` fallaban antes y
pasan ahora.

### Patron correcto ya aplicado

Las tablas de Pagos (`payments`, `payment_methods`, `money_accounts`,
`payment_components`, `payment_applications`, `refunds`, `expenses`) conceden
solo `SELECT` y su modulo escribe mediante RPC `SECURITY DEFINER`
(`create_payment`, `confirm_payment`, `cancel_payment`, `create_payment_method`,
`create_money_account`, `create_expense`, `create_refund`,
`transfer_between_accounts`). Es exactamente lo que pide
`MODULE_SECURITY_CONTRACT.md` §6 y sirve de referencia para endurecer
`inventory_transactions`.

## Clientes

### `customers`

Cliente comercial.

Columnas principales:

- `id uuid not null default extensions.gen_random_uuid()`
- `name text not null`
- `phone text`
- `email text`
- `address text`
- `tax_id text`
- `is_active boolean not null default true`
- `credit_limit numeric not null default 0`
- `current_balance numeric not null default 0`
- `province text`
- `gira text`
- metadatos de creacion/actualizacion: `created_by`,
  `created_device_name`, `created_device_identifier`, `updated_by`,
  `updated_device_name`, `updated_device_identifier`, `created_at`,
  `updated_at`

### `customer_contacts`

Personas de contacto de una empresa cliente.

Columnas:

- `id uuid not null default extensions.gen_random_uuid()`
- `customer_id uuid not null`
- `name text not null`
- `phone text`
- `role text`
- `created_by text`
- `created_device_name text`
- `created_device_identifier text`
- `created_at timestamptz not null default now()`

Relacion:

- `customer_contacts.customer_id -> customers.id`

RPCs de escritura:

- `create_customer_contact(p_customer_id, p_name, p_phone, p_role, p_actor_name, p_device_name, p_device_identifier)`
- `update_customer_contact(p_contact_id, p_name, p_phone, p_role, p_actor_name, p_device_name, p_device_identifier)`
- `delete_customer_contact(p_contact_id, p_actor_name, p_device_name, p_device_identifier)`

Nota funcional: aunque la base permite `phone` y `role` nulos, la UI de Clientes
exige nombre, telefono y cargo cuando se agrega una fila de contacto. El
contacto completo es opcional; una fila de contacto incompleta no debe guardarse.

## Relaciones principales

### Productos y promociones

- `products.category_id -> categories.id`
- `products.packaging_presentation_id -> packaging_presentations.id`
- `bulk_promotion_categories.category_id -> categories.id`
- `bulk_promotion_categories.promotion_id -> bulk_promotions.id`
- `bulk_promotion_products.product_id -> products.id`
- `bulk_promotion_products.promotion_id -> bulk_promotions.id`

### Inventario

- `inventory_locations.warehouse_id -> warehouses.id`
- `inventory_balances.product_id -> products.id`
- `inventory_balances.warehouse_id -> warehouses.id`
- `inventory_balances.location_id -> inventory_locations.id`
- `inventory_documents.origin_warehouse_id -> warehouses.id`
- `inventory_documents.origin_location_id -> inventory_locations.id`
- `inventory_documents.destination_warehouse_id -> warehouses.id`
- `inventory_documents.destination_location_id -> inventory_locations.id`
- `inventory_document_lines.document_id -> inventory_documents.id`
- `inventory_document_lines.product_id -> products.id`
- `inventory_transactions.product_id -> products.id`
- `inventory_transactions.warehouse_id -> warehouses.id`
- `inventory_transactions.location_id -> inventory_locations.id`
- `inventory_transactions.document_id -> inventory_documents.id`
- `inventory_transactions.document_line_id -> inventory_document_lines.id`
- `inventory_transactions.reversal_of_transaction_id -> inventory_transactions.id`
- `inventory_reservations.product_id -> products.id`
- `inventory_reservations.location_id -> inventory_locations.id`
- `inventory_counts.warehouse_id -> warehouses.id`
- `inventory_count_lines.count_id -> inventory_counts.id`
- `inventory_count_lines.product_id -> products.id`

### Ventas

- `customer_contacts.customer_id -> customers.id`
- `sales_quotes.customer_id -> customers.id`
- `sales_quotes.agent_id -> sales_agents.id`
- `sales_quote_lines.quote_id -> sales_quotes.id`
- `sales_quote_lines.product_id -> products.id`
- `sales_orders.customer_id -> customers.id`
- `sales_orders.agent_id -> sales_agents.id`
- `sales_orders.quote_id -> sales_quotes.id`
- `sales_orders.inventory_document_id -> inventory_documents.id`
- `sales_order_lines.order_id -> sales_orders.id`
- `sales_order_lines.product_id -> products.id`
- `sales_invoices.inventory_document_id -> inventory_documents.id`
- `sales_invoice_lines.invoice_id -> sales_invoices.id`
- `sales_invoice_lines.product_id -> products.id`
- `sales_returns.invoice_id -> sales_invoices.id`
- `sales_returns.customer_id -> customers.id`
- `sales_returns.inventory_document_id -> inventory_documents.id`
- `sales_return_lines.return_id -> sales_returns.id`
- `sales_return_lines.product_id -> products.id`
- `sales_consignments.customer_id -> customers.id`
- `sales_consignments.agent_id -> sales_agents.id`
- `sales_consignments.inventory_document_id -> inventory_documents.id`
- `sales_consignment_lines.consignment_id -> sales_consignments.id`
- `sales_consignment_lines.product_id -> products.id`

### Pagos

- `payments` es la cabecera de pago/recibo.
- `payment_components.payment_id -> payments.id`
- `payment_components.method_id -> payment_methods.id`
- `payment_components.money_account_id -> money_accounts.id`
- `payment_applications.payment_id -> payments.id`
- `refunds.payment_id -> payments.id`
- `expenses.money_account_id -> money_accounts.id`
- `money_account_transactions.from_account_id -> money_accounts.id`
- `money_account_transactions.to_account_id -> money_accounts.id`
- `unidentified_deposits.money_account_id -> money_accounts.id`
- `unidentified_deposits.payment_id -> payments.id`
- `customer_credit_entries.payment_id -> payments.id`

### Configuracion, auditoria y comandos

- `app_settings.selected_catalog_agent_id -> sales_agents.id`
- `audit_logs.action_id -> audit_actions.id`
- `packaging_presentation_create_commands.entity_id -> packaging_presentations.id`
- `sales_agent_create_commands.entity_id -> sales_agents.id`
- `sales_invoice_commands.entity_id -> sales_invoices.id`

## Objetos actuales

La base local contiene 49 tablas publicas y 2 vistas.

### Vistas

No son tablas y no admiten escritura propia:

- `catalog_agents`: vista `security_invoker` de compatibilidad sobre
  `sales_agents`. La tabla original fue renombrada en
  `20260929120000_add_configuration_sales_versioned_rpc_foundations.sql`.
- `product_catalog`: vista de catalogo.

### Tablas

`app_settings`, `audit_actions`, `audit_logs`, `bulk_promotion_categories`,
`bulk_promotion_products`, `bulk_promotions`, `carrier_create_commands`,
`carriers`, `catalog_logo_operations`, `categories`, `customer_contacts`,
`customer_credit_entries`, `customers`, `expenses`, `inventory_balances`,
`inventory_count_lines`, `inventory_counts`, `inventory_document_lines`,
`inventory_documents`, `inventory_locations`, `inventory_reservations`,
`inventory_transactions`, `money_account_transactions`, `money_accounts`,
`packaging_presentation_create_commands`, `packaging_presentations`,
`payment_applications`, `payment_commands`, `payment_components`,
`payment_methods`, `payments`, `products`, `refund_commands`, `refunds`,
`sales_agent_create_commands`, `sales_agents`, `sales_consignment_lines`,
`sales_consignments`, `sales_invoice_commands`, `sales_invoice_lines`,
`sales_invoices`, `sales_order_lines`, `sales_orders`, `sales_quote_lines`,
`sales_quotes`, `sales_return_lines`, `sales_returns`, `unidentified_deposits`,
`warehouses`.
