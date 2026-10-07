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
`set local role authenticated` dentro de `rollback`. **Las cuatro excepciones
quedaron cerradas el 2026-10-03.**

| Objeto | Situacion | Estado |
|---|---|---|
| `inventory_transactions` | Aceptaba `INSERT` directo y `TRUNCATE` | **Cerrado** por `20261003100000_harden_inventory_ledger.sql` |
| `inventory_balances` | Concedia `TRUNCATE,REFERENCES,TRIGGER` | **Cerrado** por la misma migracion |
| `audit_logs` | Concedia `INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER` y `TRUNCATE` **borraba el historial completo** | **Cerrado** por `20261003110000_harden_audit_trail.sql` |
| `catalog_logo_operations` | Politica RLS `ALL` y `TRUNCATE` sin freno | **Cerrado** por la misma migracion |

`audit_actions` tenia politica `ALL` sin conceder privilegio; se selló tambien
por defensa en profundidad.

#### Storage: protegido, con un residuo que no se puede cerrar desde aqui

`storage.objects` concede a `anon` y `authenticated` `TRUNCATE`, `REFERENCES` y
`TRIGGER` ademas del CRUD. Sobre el papel es el mismo vector que vacio
`inventory_transactions` y `audit_logs`. **No es explotable igual:**

1. PostgREST **no expone** el schema `storage` (`supabase/config.toml`:
   `schemas = ["public", "graphql_public"]`). La aplicacion usa el API de
   Storage (`_client.storage.from(...)`), que es otro servicio.
2. Quien otorga esos privilegios es `supabase_storage_admin`, y **`postgres`
   no es superuser** en la base local de Supabase. Un `REVOKE` desde `postgres`
   **no los quita**: PostgreSQL reporta `REVOKE` igual aunque no haya revocado
   nada. Comprobado: `has_table_privilege` sigue en `true` justo despues.

Riesgo residual: acceso SQL directo con credenciales de base, fuera del modelo
de amenazas de la aplicacion de escritorio. **No se aplica un `REVOKE` que no
hace nada**, para no dar una falsa sensacion de proteccion.

Sobre `storage.objects` **no** se anade trigger `BEFORE TRUNCATE`: es una tabla
gestionada por Supabase y tocar su esquema puede romperse en una actualizacion.
Es una decision, no un olvido.

Lo que si protege de verdad, y esta cubierto por `storage_hardening_test.sql`:
politicas acotadas a su bucket y a un patron de nombre, `catalog-assets` sin
politica de `DELETE` (el logo no se puede borrar), los dos buckets con limite de
tamano y solo tipos de imagen, y el trigger `protect_objects_delete` que impide
el borrado directo de objetos.

#### Leccion comun de los dos huecos

En ambos casos la capa que falto fue la misma: **`TRUNCATE` no lo cubre RLS**
(no es una operacion por fila) **ni los triggers `BEFORE DELETE`**. Las tablas
inmutables deben blindarlo con un trigger `BEFORE TRUNCATE` aparte, no confiar
en el privilegio ni en el trigger de borrado.

Descartado tras verificarlo: `write_audit_log` **no** permite falsificar
auditoria. Es funcion de `trigger`, invocable solo desde un trigger.

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
`.specs/architecture/module-security-contract.md` §6 y sirve de referencia para endurecer
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

### Actualizaciones Pendientes
- **RPC Bulk Insert:** `create_product_with_initial_stock` debe mapear `is_active = coalesce((p_product->>'is_active')::boolean, true)`.
- **Indexación y optimización:** Faltan índices `pg_trgm` en `products` (`sku`, `name`) y `customers` (`name`, `tax_id`, `phone`).
