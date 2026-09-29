# SDD - Módulo 1: Gestión de Productos y Catálogos

## 1. Descripción general

El Módulo 1 permite gestionar productos, categorías, promociones individuales y
masivas, importaciones y exportaciones y catálogos PDF personalizados. El stock
y sus movimientos pertenecen al módulo independiente de Inventario; Productos
consume su API para mostrar existencias e historiales relacionados.

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
- `audit_logs` registra cambios en productos, categorías y promociones. Los
  movimientos de inventario forman un libro inmutable propio, según
  `SDD_Modulo_Inventario.md`.
- Los módulos siguen la estructura definida en `MODULE_STRUCTURE.md` y se comunican exclusivamente mediante sus API públicas.

Productos e Inventario se comunican mediante sus índices y API públicas. Los
providers de revisión pública notifican cambios de stock o historial sin
importar el `di/` o la presentación interna del otro módulo.

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
| Metadatos comunes | Varios | Creación y modificación; la eliminación de categorías es física y auditada. |

#### Gestión y eliminación de categorías

Una categoría es una agrupación modificable de productos y no representa un
documento comercial histórico. Por decisión funcional, su eliminación es
física. Antes de eliminar una categoría que contiene productos, el usuario debe
seleccionar otra categoría activa y todos los productos se reasignan de forma
atómica. No se permite eliminar la última categoría activa. También se eliminan
sus relaciones con promociones masivas y se registra una acción legible en
`audit_logs`; los productos nunca se eliminan junto con la categoría.

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
| `packaging_presentation_id` | UUID, FK | Presentación configurable obligatoria, por ejemplo Unidad, Caja, Set o Cartón. |
| `cbm_per_moq` | Decimal | Volumen correspondiente al MOQ. |
| `factory_cost` | Numeric(18,2) | Costo de fábrica antes de importación. |
| `image_url` | String, nullable | URL de la imagen optimizada en Supabase Storage. |
| `image_position_x` | Decimal | Punto focal horizontal de la fotografía. |
| `image_position_y` | Decimal | Punto focal vertical de la fotografía. |
| `image_scale` | Decimal | Zoom persistente aplicado a la fotografía. |
| `catalog_sort_order` | Integer | Posición del producto dentro de su categoría en el catálogo. |
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

### 4.3 Referencia a `inventory_transactions`

Esta tabla es el libro contable inmutable del módulo de Inventario. Su esquema,
reglas y flujos se definen en `SDD_Modulo_Inventario.md`; se conserva aquí solo
la referencia necesaria para explicar `products.current_stock`.

Productos solo necesita conocer que cada movimiento válido actualiza el stock de
forma atómica y que el historial se consulta mediante la API pública de
Inventario.

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

La selección por una o varias categorías utiliza semántica **dinámica**. La
relación se conserva en `bulk_promotion_categories`; mientras la promoción esté
activa, cualquier producto que pertenezca posteriormente a una de esas
categorías también recibe la promoción. La selección manual sí conserva una
lista explícita en `bulk_promotion_products`.

`bulk_promotion_products.conditions_text` permite guardar una condición
particular para un producto, adicional a la condición general de la campaña.

#### Validación del editor de promociones

- El nombre es obligatorio.
- El descuento solo acepta números con hasta dos decimales, usando punto o coma.
- El porcentaje debe ser mayor que cero y menor o igual que cien.
- El alcance manual exige al menos un producto y el alcance por categoría exige
  al menos una categoría.
- Un error de validación o persistencia se muestra dentro del formulario y no lo
  cierra; durante el guardado se impiden envíos duplicados.

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
- Presentación configurable y cantidad mínima de venta para el catálogo.
- MOQ de recompra, CBM y costo de fábrica como información interna de abastecimiento.
- Precio unitario, precio por paquete y gestión de márgenes.
- Compresión local de imágenes antes de subirlas.
- La imagen se almacena como `<SKU>.JPG`; al reemplazarla se elimina el objeto anterior y la nueva URL incorpora una versión para evitar caché obsoleta.
- Cada producto conserva punto focal horizontal, punto focal vertical y zoom
  para controlar su fotografía en la lista, ficha y catálogo.
- En edición se puede activar nuevamente un producto inactivo; la reactivación limpia los metadatos de eliminación lógica.
- El stock inicial genera una transacción `INITIAL_STOCK`; nunca escribe directamente en `current_stock`.

### Pantalla C: ficha técnica

- Información de compra e importación.
- Calculadora de precio basada en costo, importación y margen.
- Historial de cambios de `factory_cost` mediante `audit_logs`.
- Historial completo e inmutable de inventario.
- Cuando el stock llega a cero, la ficha calcula y muestra la fecha en que se agotó a partir del libro de movimientos.
- Promoción activa y regla de prioridad aplicada.
- Espacios para futuros módulos de inventario avanzado, ventas, CRM y reportes.

### Pantalla de auditoría

- Búsqueda local por tabla, registro, operación, campo, valores, usuario o dispositivo, con limpieza inmediata del filtro.
- Las modificaciones del mismo registro y momento se consolidan en una acción expandible. Productos y categorías se muestran por SKU/nombre y los productos incluyen enlace a su ficha.
- Filtro por fecha inicial y final.

### Pantalla D: generador avanzado de PDF

- Diseños de 1, 2, 4 o 6 tarjetas por página y lista compacta. La cuadrícula reserva automáticamente una página completa, media página, un cuarto o un sexto para cada producto, y escala la fotografía según ese espacio.
- Portada con logo, nombre de empresa y métodos de pago. El logo se administra
  exclusivamente desde Configuración.
- Empresa y métodos de pago provienen exclusivamente de Configuración; el generador mantiene sólo datos propios del documento, selección, diseño y colores.
- Colores configurables mediante selector RGB o código hexadecimal `#RRGGBB`: fondo, tarjeta, elemento de diseño, fuente principal, fuente destacada, fuente secundaria, elemento de promoción y fuente de promoción.
- Ajuste de fotografías configurable entre rellenar y recortar, mostrar la imagen completa o ajustar al ancho.
- El punto focal configurado en cada producto también controla el recorte del PDF.
- Los productos inactivos o agotados se excluyen tanto en la interfaz como dentro del servicio generador.
- El usuario puede reordenar uno o varios productos dentro de su categoría; el PDF conserva ese orden y nunca divide visualmente una categoría con productos de otra.
- Los colores promocionales separan distintivo/fuente, precio anterior, precio actual y texto de promoción.
- Datos del agente y QR de WhatsApp generado localmente.
- Portadas o separadores por categoría según el diseño.
- SKU, descripción, precio unitario, empaque y MOQ.
- Sello promocional sobre la imagen.
- Precio anterior tachado, precio final destacado y condiciones de promoción.
- El diseño, los colores, la cantidad de tarjetas, el ajuste de imagen, el logo
  y el agente seleccionado se conservan en `app_settings`.
- El catálogo conserva el orden persistente de categorías y productos.
- Las listas extensas de selección y orden incluyen búsqueda, desplazamiento y
  limpieza de selección.
- La acción final guarda el PDF en una ubicación elegida por el usuario.

### Pantalla E: importación y exportación masiva

- Exportación e importación de productos mediante CSV compatible con hojas de
  cálculo.
- Validación de filas, campos obligatorios, categorías y presentaciones.
- Asociación y transporte masivo de imágenes mediante un paquete comprimido.
- Los errores deben identificar la fila y el campo afectado sin interrumpir la
  revisión del resto del archivo.
- SKU y código de barras deben respetar sus restricciones de unicidad.

## 6. Integridad: base de datos frente a aplicación

Las reglas que protegen la integridad de los datos deben ejecutarse en PostgreSQL: claves, restricciones, inmutabilidad, actualización atómica de stock y auditoría. Las reglas de experiencia de usuario, presentación y coordinación de casos de uso permanecen en Dart.

Esto no reemplaza las validaciones de la aplicación. La aplicación valida para ofrecer mensajes claros e interacción inmediata; PostgreSQL vuelve a validar para impedir inconsistencias por concurrencia, errores de programación o futuros clientes que escriban en la misma base de datos.

## 7. Estado de decisiones de implementación

- Selección promocional por categorías: dinámica; incluye productos que entren
  posteriormente en una categoría seleccionada.
- Impuestos y redondeo: configurables mediante `app_settings`; la aplicación conserva USD y dos decimales como valores iniciales.
- RLS: existen políticas locales provisionales para los roles `anon` y `authenticated`; deben reemplazarse por políticas basadas en roles al incorporar autenticación.
- Identificación provisional: la aplicación obtiene el nombre del equipo y la primera dirección MAC disponible; si el sistema no permite leerla, usa el nombre del equipo como identificador de respaldo.
- Stock negativo y operación sin conexión: permitidos conforme a las reglas de
  alerta, idempotencia y resolución de conflictos de
  `SDD_Modulo_Inventario.md`.

## 8. Estado y deuda técnica

- El módulo consume Inventario mediante `inventory_module.dart` y su API pública.
- Crear o editar una promoción, su alcance y sus condiciones particulares se
  ejecuta mediante `save_bulk_promotion` en una única transacción PostgreSQL.
  Cualquier fallo revierte toda la operación y conserva el estado anterior.
- Las presentaciones se administran exclusivamente mediante
  `packaging_presentations`; los productos anteriores fueron migrados y el enum
  fijo `packaging_type` fue retirado.
- Empresa, pagos, logo, preferencias del catálogo y presentaciones pertenecen
  al módulo Configuración. Productos los consume exclusivamente mediante
  `configuration_module.dart`.
