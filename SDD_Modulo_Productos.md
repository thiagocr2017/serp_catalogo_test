# SDD - Módulo 1: Gestión de Productos, Catálogos e Inventario Base

## 1. Descripción general

El Módulo 1 permite gestionar el ciclo de vida del producto mediante CRUD con eliminación lógica, mantener trazabilidad estricta, gestionar promociones individuales y masivas y generar PDF dinámicos con personalización temática. También establece las bases aisladas del futuro módulo de inventario.

Todas las tablas, columnas y variables del código se escriben en inglés. La interfaz y la documentación funcional se mantienen en español.

## 2. Decisiones de arquitectura

- Riverpod 3 se utiliza para gestión de estado e inyección de dependencias.
- `ProviderScope` se instala en la raíz de la aplicación.
- El dominio permanece independiente de Riverpod; los providers se limitan a
  `di/` y los controladores reactivos a `presentation/controllers/`.
- El código de `inventory_transactions` pertenece al módulo independiente `modules/inventory` y no se mezcla con el módulo `product`.
- Los PDF se procesan localmente en la Mac y no se suben a la nube.
- Las imágenes optimizadas se almacenan en Supabase Storage.
- PostgreSQL es la fuente de verdad de productos, movimientos, promociones y auditoría.
- `audit_logs` registra los cambios de las tablas importantes, incluyendo `products`, `inventory_transactions` y `bulk_promotions`.
- Los módulos siguen la estructura definida en `MODULE_STRUCTURE.md` y se comunican exclusivamente mediante sus API públicas.

## 3. Reglas transversales

### 3.1 Metadatos comunes

Las tablas mutables deben quedar preparadas, según corresponda, con:

| Columna | Tipo | Descripción |
|---|---|---|
| `created_at` | Timestamp | Fecha de creación. |
| `updated_at` | Timestamp, nullable | Fecha de última modificación. |
| `created_by` | String, nullable | Usuario o dispositivo que creó el registro. |
| `updated_by` | String, nullable | Usuario o dispositivo que hizo el último cambio. |
| `deleted_at` | Timestamp, nullable | Fecha de eliminación lógica. |
| `deleted_by` | String, nullable | Usuario o dispositivo que desactivó el registro. |
| `is_active` | Boolean | Estado lógico del registro cuando aplique. |

Las tablas inmutables, como `inventory_transactions`, no tendrán campos que sugieran edición o eliminación.

### 3.2 Identificación provisional del actor

Hasta implementar autenticación, cada operación auditable identificará la estación de trabajo mediante:

| Columna | Tipo | Descripción |
|---|---|---|
| `actor_user_id` | UUID, nullable | Usuario autenticado cuando exista el módulo de Auth. |
| `actor_name` | String, nullable | Nombre visible del usuario cuando esté disponible. |
| `device_name` | String | Nombre de la computadora. |
| `device_identifier` | String | Identificador del dispositivo; inicialmente la dirección MAC. |

La dirección MAC identifica provisionalmente al dispositivo, no garantiza la identidad de la persona y puede cambiar o falsificarse. Cuando exista autenticación, `actor_user_id` será la identificación principal y los datos del equipo se conservarán como contexto de auditoría.

### 3.3 Dinero y configuración

- La moneda inicial es USD.
- Los importes utilizan dos decimales.
- En PostgreSQL, los valores monetarios deben usar `NUMERIC(18, 2)`, nunca tipos de punto flotante.
- Impuestos, precios con o sin impuestos y reglas de redondeo serán definidos por el futuro módulo `setup` o `configuration`.
- Los documentos y operaciones que necesiten preservar contexto histórico deben almacenar su `currency_code`.

La configuración futura debe contemplar, como mínimo: `default_currency`, `decimal_places`, `tax_percentage`, `prices_include_tax`, `rounding_mode` y `rounding_increment`.

## 4. Esquema de base de datos

### 4.1 `categories`

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | UUID, PK | Identificador único. |
| `name` | String | Nombre de la categoría. |
| Metadatos comunes | Varios | Creación, modificación y eliminación lógica. |

### 4.2 `products`

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | UUID, PK | Identificador único. |
| `sku` | String, Unique | Código interno del producto. |
| `barcode` | String, Unique, nullable | Código de barras para escáner. |
| `name` | String | Nombre o título interno. |
| `description` | Text | Descripción para catálogo. |
| `category_id` | UUID, FK | Relación con `categories`. |
| `unit_price` | Numeric(18,2) | Precio por unidad en la moneda configurada. |
| `package_price` | Numeric(18,2), nullable | Precio por paquete o caja. |
| `min_order_quantity` | Integer | Cantidad mínima de compra. |
| `minimum_sale_quantity` | Integer | Cantidad mínima que se vende al cliente; es independiente del MOQ de recompra. |
| `packaging_type` | String | Tipo de empaque: caja, set o unidad. |
| `cbm_per_moq` | Decimal | Volumen correspondiente al MOQ. |
| `factory_cost` | Numeric(18,2) | Costo de fábrica antes de importación. |
| `image_url` | String, nullable | URL de la imagen optimizada en Supabase Storage. |
| `current_stock` | Integer | Valor de solo lectura actualizado por movimientos de inventario. |
| `reorder_point` | Integer | Límite de alerta para recomprar stock. |
| `promo_price` | Numeric(18,2), nullable | Precio de promoción individual. |
| `promo_text` | String, nullable | Condiciones de la promoción individual. |
| Metadatos comunes | Varios | Creación, modificación y eliminación lógica. |

#### Regla de `current_stock`

`current_stock` es un valor persistido para consulta rápida, pero no puede modificarse directamente desde la interfaz ni desde el repositorio de productos. Su única vía de actualización es la creación de una transacción válida de inventario:

```text
new current_stock = previous current_stock + transaction.quantity
```

La inserción de la transacción y la actualización del stock deben ejecutarse dentro de una única transacción de PostgreSQL. Preferentemente, una función y un trigger de PostgreSQL realizarán la actualización automática para garantizar que cualquier origen de datos respete la misma regla.

### 4.3 `inventory_transactions`

Esta tabla es el libro contable inmutable del inventario.

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | UUID, PK | Identificador de la transacción. |
| `product_id` | UUID, FK | Producto afectado. |
| `quantity` | Integer | Positivo para una entrada y negativo para una salida. No puede ser cero. |
| `reason` | Enum | `INITIAL_STOCK`, `PURCHASE`, `SALE`, `ADJUSTMENT`, `RETURN` o `REVERSAL`. |
| `reversal_of_transaction_id` | UUID, FK, nullable | Movimiento original que este registro corrige. |
| `notes` | Text, nullable | Justificación o referencia del movimiento. |
| `actor_user_id` | UUID, nullable | Usuario autenticado futuro. |
| `actor_name` | String, nullable | Nombre del actor cuando esté disponible. |
| `device_name` | String | Computadora que originó el movimiento. |
| `device_identifier` | String | Identificador de la computadora. |
| `created_at` | Timestamp | Momento del movimiento. |

#### Inmutabilidad

- Solo se permite `INSERT`; se bloquean `UPDATE` y `DELETE` en PostgreSQL.
- Un error se corrige creando una transacción compensatoria, nunca editando el historial.
- Una corrección debe usar `reversal_of_transaction_id` para enlazar el movimiento original cuando corresponda.
- No existen `updated_at`, `deleted_at`, `updated_by` ni `deleted_by` en esta tabla.
- La operación que inserta el movimiento también actualiza `products.current_stock` de manera atómica.

Ejemplo: si se registraron `+100` unidades y debían ser `+10`, se conserva el movimiento original y se registra una corrección de `-90`.

### 4.4 `bulk_promotions`

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | UUID, PK | Identificador de la campaña. |
| `name` | String | Nombre de la campaña. |
| `discount_percentage` | Decimal | Porcentaje de descuento. |
| `conditions_text` | Text | Condiciones mostradas en los PDF. |
| `badge_image_url` | String, nullable | URL del sello PNG transparente. |
| `start_date` | Timestamp, nullable | Inicio programado de la promoción. |
| `end_date` | Timestamp | Fecha de desactivación automática. |
| `applies_to_all_products` | Boolean | Indica si incluye todos los productos elegibles. |
| Metadatos comunes | Varios | Creación, modificación, activación y eliminación lógica. |

### 4.5 Selección de productos en promociones masivas

Al crear una promoción, la interfaz permitirá seleccionar todos los productos, los productos de una o varias categorías o una selección específica.

Las selecciones se guardan mediante las tablas de relación `bulk_promotion_products` (`promotion_id`, `product_id`) y `bulk_promotion_categories` (`promotion_id`, `category_id`).

La selección por una o varias categorías utiliza semántica **congelada**: al crear la promoción se guardan en `bulk_promotion_products` los productos que pertenecen a las categorías seleccionadas en ese momento. Los productos agregados posteriormente no entran automáticamente en la campaña. Esta decisión evita incorporaciones accidentales y conserva el alcance comercial original.

### 4.6 Prioridad de promociones

Las promociones no se acumulan. La prioridad es:

```text
promoción individual > promoción masiva > precio normal
```

Si un producto tiene una promoción individual vigente, esta reemplaza cualquier promoción masiva aplicable. El cálculo debe informar el precio original, el precio final y el tipo de promoción aplicada.

### 4.7 `audit_logs`

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | UUID, PK | Identificador del log. |
| `table_name` | String | Tabla afectada. |
| `record_id` | UUID | Registro modificado. |
| `operation` | Enum | `INSERT`, `UPDATE`, `SOFT_DELETE` u otra operación permitida. |
| `field_name` | String, nullable | Campo modificado. |
| `old_value` | Text, nullable | Valor anterior serializado. |
| `new_value` | Text, nullable | Valor nuevo serializado. |
| `actor_user_id` | UUID, nullable | Usuario autenticado futuro. |
| `actor_name` | String, nullable | Nombre del actor. |
| `device_name` | String | Nombre de la computadora. |
| `device_identifier` | String | Identificador de la computadora. |
| `created_at` | Timestamp | Momento del cambio. |

Los registros de auditoría son inmutables. La captura mediante triggers de PostgreSQL asegura que los cambios queden registrados aunque en el futuro existan varios clientes o procesos escribiendo en la base de datos.

## 5. Interfaz y flujos

### Pantalla A: lista avanzada de productos

- Cuadrícula o lista con nombre, descripción y foto.
- Filtros por estado, alerta de stock, categoría y rango de precios.
- Selección múltiple para PDF y promociones.
- Acceso a la ficha técnica, creación de productos y exportación.

### Pantalla B: formulario de producto

- Código de barras, SKU, nombre, categoría y descripción.
- Tipo de empaque y cantidad mínima de venta para el catálogo.
- MOQ de recompra, CBM y costo de fábrica como información interna de abastecimiento.
- Precio unitario, precio por paquete y gestión de márgenes.
- Compresión local de imágenes antes de subirlas.
- El stock inicial genera una transacción `INITIAL_STOCK`; nunca escribe directamente en `current_stock`.

### Pantalla C: ficha técnica

- Información de compra e importación.
- Calculadora de precio basada en costo, importación y margen.
- Historial de cambios de `factory_cost` mediante `audit_logs`.
- Historial completo e inmutable de inventario.
- Promoción activa y regla de prioridad aplicada.
- Espacios para futuros módulos de inventario avanzado, ventas, CRM y reportes.

### Pantalla D: generador avanzado de PDF

- Diseños de 1, 2, 3, 4 o 6 tarjetas por página y lista compacta.
- Portada con logo, nombre de empresa y métodos de pago.
- Datos del agente y QR de WhatsApp generado localmente.
- Portadas o separadores por categoría según el diseño.
- SKU, descripción, precio unitario, empaque y MOQ.
- Sello promocional sobre la imagen.
- Precio anterior tachado, precio final destacado y condiciones de promoción.

## 6. Integridad: base de datos frente a aplicación

Las reglas que protegen la integridad de los datos deben ejecutarse en PostgreSQL: claves, restricciones, inmutabilidad, actualización atómica de stock y auditoría. Las reglas de experiencia de usuario, presentación y coordinación de casos de uso permanecen en Dart.

Esto no reemplaza las validaciones de la aplicación. La aplicación valida para ofrecer mensajes claros e interacción inmediata; PostgreSQL vuelve a validar para impedir inconsistencias por concurrencia, errores de programación o futuros clientes que escriban en la misma base de datos.

## 7. Estado de decisiones de implementación

- Selección por categorías: resuelta como selección congelada de productos.
- Impuestos y redondeo: configurables mediante `app_settings`; la aplicación conserva USD y dos decimales como valores iniciales.
- RLS: existen políticas locales provisionales para los roles `anon` y `authenticated`; deben reemplazarse por políticas basadas en roles al incorporar autenticación.
- Identificación provisional: la aplicación obtiene el nombre del equipo y la primera dirección MAC disponible; si el sistema no permite leerla, usa el nombre del equipo como identificador de respaldo.
- Tratamiento de salidas que intentarían dejar el stock por debajo de cero.
- Estrategia de sincronización y recuperación ante pérdida de conexión.
