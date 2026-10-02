# SDD - Módulo 3: Ventas

## 1. Descripción general

El módulo de Ventas administra agentes, clientes, cotizaciones, pedidos, facturas, devoluciones y consignaciones. Coordina su impacto en Inventario mediante operaciones atómicas en PostgreSQL.

## 2. Funcionalidad implementada

### Agentes
- Pantalla propia accesible desde `Ventas > Agentes`.
- Creación, edición, desactivación lógica de agentes.
- Selección de un agente para el catálogo PDF.

### Clientes
- CRUD completo de clientes con nombre, teléfono, email, dirección, tax ID.
- Límite de crédito y saldo actual.
- Desactivación lógica.

### Cotizaciones
- Creación de cotizaciones con líneas de producto.
- Estados: DRAFT, SENT, ACCEPTED, REJECTED, EXPIRED, CONVERTED.
- Fecha de validez.
- Asignación de agente.

### Pedidos
- Creación de pedidos con líneas de producto.
- Estados: DRAFT, CONFIRMED, RESERVED, DISPATCHED, DELIVERED, CANCELLED.
- Creación atómica con documento de inventario SALE_DISPATCH.
- Descuento automático de stock.
- Vinculación a cotización (opcional).
- Asignación de agente.

### Facturas de venta
- Creación de facturas con líneas de producto.
- Estados: DRAFT, CONFIRMED, CANCELLED, PAID.
- Creación atómica con documento de inventario SALE_DISPATCH.
- Descuento automático de stock.
- Cancelación con reversión de stock.

### Devoluciones
- Creación de devoluciones vinculadas a facturas.
- Estados: DRAFT, CONFIRMED, CANCELLED.
- Creación atómica con documento de inventario CUSTOMER_RETURN.
- Reversión automática de stock.

### Consignaciones
- Creación de consignaciones con líneas de producto.
- Estados: DRAFT, SENT, PARTIAL_RETURN, RETURNED, SETTLED, CANCELLED.
- Creación atómica con documento de inventario CONSIGNMENT.
- Registro de devoluciones parciales.
- Asignación de agente.

## 3. Modelos de datos

### `customers`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | Identificador. |
| `name` | Text | Nombre del cliente. |
| `phone` | Text | Teléfono. |
| `email` | Text | Email. |
| `address` | Text | Dirección. |
| `tax_id` | Text | Identificación fiscal. |
| `is_active` | Boolean | Estado lógico. |
| `credit_limit` | Numeric(18,2) | Límite de crédito. |
| `current_balance` | Numeric(18,2) | Saldo actual. |

### `sales_quotes`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | Identificador. |
| `quote_number` | Text | Número de cotización (COT-XXXXXX). |
| `customer_id` | UUID | Cliente. |
| `customer_name` | Text | Nombre del cliente (snapshot). |
| `status` | Text | Estado de la cotización. |
| `total_amount` | Numeric(18,2) | Total. |
| `currency_code` | Char(3) | Moneda. |
| `exchange_rate` | Numeric(18,6) | Tipo de cambio. |
| `valid_until` | Date | Fecha de validez. |
| `agent_id` | UUID | Agente asignado. |

### `sales_orders`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | Identificador. |
| `order_number` | Text | Número de pedido (PED-XXXXXX). |
| `customer_id` | UUID | Cliente. |
| `customer_name` | Text | Nombre del cliente (snapshot). |
| `status` | Text | Estado del pedido. |
| `total_amount` | Numeric(18,2) | Total. |
| `currency_code` | Char(3) | Moneda. |
| `exchange_rate` | Numeric(18,6) | Tipo de cambio. |
| `quote_id` | UUID | Cotización de origen (opcional). |
| `inventory_document_id` | UUID | Documento de inventario vinculado. |
| `agent_id` | UUID | Agente asignado. |

### `sales_invoices`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | Identificador. |
| `invoice_number` | Text | Número de factura (FAC-XXXXXX). |
| `customer_id` | UUID | Cliente. |
| `customer_name` | Text | Nombre del cliente (snapshot). |
| `status` | Text | Estado de la factura. |
| `total_amount` | Numeric(18,2) | Total. |
| `currency_code` | Char(3) | Moneda. |
| `exchange_rate` | Numeric(18,6) | Tipo de cambio. |
| `inventory_document_id` | UUID | Documento de inventario vinculado. |

### `sales_returns`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | Identificador. |
| `return_number` | Text | Número de devolución (DEV-XXXXXX). |
| `invoice_id` | UUID | Factura de origen. |
| `customer_id` | UUID | Cliente. |
| `customer_name` | Text | Nombre del cliente (snapshot). |
| `status` | Text | Estado de la devolución. |
| `total_amount` | Numeric(18,2) | Total. |
| `reason` | Text | Motivo de la devolución. |
| `inventory_document_id` | UUID | Documento de inventario vinculado. |

### `sales_consignments`
| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID | Identificador. |
| `consignment_number` | Text | Número de consignación (CON-XXXXXX). |
| `customer_id` | UUID | Cliente. |
| `customer_name` | Text | Nombre del cliente (snapshot). |
| `status` | Text | Estado de la consignación. |
| `total_amount` | Numeric(18,2) | Total enviado. |
| `returned_amount` | Numeric(18,2) | Total devuelto. |
| `currency_code` | Char(3) | Moneda. |
| `agent_id` | UUID | Agente asignado. |
| `inventory_document_id` | UUID | Documento de inventario vinculado. |

## 4. Arquitectura

```text
lib/modules/sales/
├── api/
│   ├── sales_api.dart              # Agentes
│   ├── sales_invoice_api.dart      # Facturas
│   ├── customer_api.dart           # Clientes
│   ├── quote_api.dart              # Cotizaciones
│   ├── order_api.dart              # Pedidos
│   ├── return_api.dart             # Devoluciones
│   ├── consignment_api.dart        # Consignaciones
│   └── sales_routes.dart           # Rutas
├── domain/
│   ├── entities/
│   │   ├── sales_invoice.dart
│   │   ├── customer.dart
│   │   ├── sales_quote.dart
│   │   ├── sales_order.dart
│   │   ├── sales_return.dart
│   │   └── sales_consignment.dart
│   └── repositories/
│       ├── sales_repository.dart
│       ├── sales_invoice_repository.dart
│       ├── customer_repository.dart
│       ├── quote_repository.dart
│       ├── order_repository.dart
│       ├── return_repository.dart
│       └── consignment_repository.dart
├── data/
│   ├── data_sources/
│   │   ├── supabase_sales_data_source.dart
│   │   ├── supabase_sales_invoice_data_source.dart
│   │   ├── supabase_customer_data_source.dart
│   │   ├── supabase_quote_data_source.dart
│   │   ├── supabase_order_data_source.dart
│   │   ├── supabase_return_data_source.dart
│   │   └── supabase_consignment_data_source.dart
│   └── repositories/
│       ├── supabase_sales_repository.dart
│       ├── supabase_sales_invoice_repository.dart
│       ├── supabase_customer_repository.dart
│       ├── supabase_quote_repository.dart
│       ├── supabase_order_repository.dart
│       ├── supabase_return_repository.dart
│       └── supabase_consignment_repository.dart
├── presentation/
│   └── pages/
│       ├── agent_page.dart
│       ├── invoices_page.dart
│       ├── customers_page.dart
│       ├── quotes_page.dart
│       ├── orders_page.dart
│       ├── returns_page.dart
│       └── consignments_page.dart
├── di/
│   └── sales_providers.dart
└── sales_module.dart
```

## 5. Reglas vigentes

- Un agente inactivo no puede seleccionarse para nuevos catálogos o documentos.
- Desactivar un agente no elimina documentos históricos.
- Los documentos deben conservar el nombre, moneda, impuestos y precios que tenían al emitirse, aunque la configuración cambie posteriormente.
- Una venta confirmada no se corrige borrando movimientos de inventario.
- Un pedido reserva inventario sin disminuir el stock físico.
- Anular un pedido libera su reserva.
- Confirmar una venta libera la reserva y crea la salida física en una única transacción.
- Una venta sincronizada desde operación offline debe utilizar un identificador idempotente para impedir duplicados.
- Las facturas, pedidos, devoluciones y consignaciones se crean de forma atómica con su documento de inventario correspondiente.

## 6. Integración con otros módulos

- **Inventario**: Los pedidos, facturas, devoluciones y consignaciones crean documentos de inventario atómicamente.
- **Pagos**: Las facturas pueden recibir pagos (vía `payment_applications`).
- **Configuración**: Las cotizaciones y pedidos usan la moneda y configuración de la empresa.
- **Productos**: Las líneas de documentos referencian productos con snapshot de SKU y nombre.

## 7. Deuda técnica

- Las pantallas de documentos son listas de solo lectura; falta UI para crear/editar.
- No existe conversión de cotización a pedido (CONVERTED).
- No existe liquidación de consignación (SETTLED).
- No existe integración con Pagos para marcar facturas como PAID.
- No existe búsqueda ni filtros avanzados en las pantallas.
- Los formularios de Ventas deben mantener el diálogo abierto y mostrar el error
  cuando el usuario intenta guardar datos inválidos. La cobertura inicial valida
  el formulario de agentes; los documentos comerciales se probarán cuando sus
  pantallas de creación/edición estén implementadas.
