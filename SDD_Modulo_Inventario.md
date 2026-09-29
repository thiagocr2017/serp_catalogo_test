# SDD - Módulo 2: Gestión de Inventario y Auditoría

## 1. Descripción general

El módulo de Inventario administra el libro inmutable de existencias, el stock
actual derivado de sus movimientos y la consulta consolidada de auditoría. Es
independiente de Productos y debe consumir únicamente su API pública para
identificar los productos afectados.

## 2. Estado actual

Se encuentran implementados:

- stock inicial al crear un producto;
- compras o entradas;
- ventas o salidas;
- ajustes positivos y negativos;
- devoluciones;
- correcciones mediante reversión;
- historial general y por producto, ordenado del más reciente al más antiguo;
- búsqueda por SKU, motivo, notas, cantidad o fecha;
- consulta de auditoría con búsqueda, fechas, consolidación y enlaces a recursos.

## 3. Arquitectura

El módulo vive en `lib/modules/inventory/` y sigue la estructura definida en
`MODULE_STRUCTURE.md`. PostgreSQL es la fuente de verdad. Riverpod conecta la
interfaz `InventoryRepository` con `SupabaseInventoryRepository`.

Inventario obtiene productos mediante `product_module.dart` y su API pública.
Los cambios de stock notifican a Productos mediante un provider público de
revisión, sin importar providers o controladores internos.

## 4. Entidad `inventory_transactions`

| Campo | Tipo | Regla |
|---|---|---|
| `id` | UUID | Identificador único. |
| `product_id` | UUID, FK | Producto afectado. |
| `quantity` | Integer | No puede ser cero. |
| `reason` | Enum | `INITIAL_STOCK`, `PURCHASE`, `SALE`, `ADJUSTMENT`, `RETURN` o `REVERSAL`. |
| `reversal_of_transaction_id` | UUID, nullable | Movimiento corregido por una reversión. |
| `notes` | Text, nullable | Motivo o referencia humana. |
| `actor_user_id` | UUID, nullable | Usuario autenticado futuro. |
| `actor_name` | Text, nullable | Actor visible disponible. |
| `device_name` | Text | Nombre del equipo. |
| `device_identifier` | Text | Identificador provisional del equipo. |
| `created_at` | Timestamp | Fecha inmutable del movimiento. |

## 5. Reglas de cantidades

- Las ventas se almacenan siempre como cantidades negativas.
- Las compras y devoluciones se almacenan como cantidades positivas.
- Los ajustes conservan el signo introducido.
- El stock inicial se almacena como entrada positiva.
- Una reversión usa la cantidad opuesta al movimiento original y guarda su
  identificador en `reversal_of_transaction_id`.
- Solo puede existir una reversión directa por movimiento.

## 6. Stock actual y atomicidad

`products.current_stock` es una proyección persistida de solo lectura:

```text
nuevo stock = stock anterior + cantidad del movimiento
```

La aplicación no modifica directamente este valor. Un trigger PostgreSQL lo
actualiza después de insertar la transacción, dentro de la misma operación de
base de datos. Si el producto no existe, toda la operación falla.

## 7. Inmutabilidad y correcciones

PostgreSQL bloquea `UPDATE` y `DELETE` sobre `inventory_transactions`. Un error
se corrige insertando una reversión; nunca se reescribe el historial. El libro
de movimientos funciona como registro primario auditable del inventario.

Actualmente `audit_logs` no duplica cada transacción de inventario. La
actualización resultante del stock sí puede producir auditoría sobre Productos.
Esto evita duplicar la misma acción en dos historiales; si en el futuro se exige
un registro transversal único, deberá agregarse deliberadamente un evento
consolidado.

## 8. Interfaz

### Movimientos

- Selector de producto activo mostrando SKU y nombre.
- Motivo del movimiento.
- Cantidad con ayuda contextual sobre el signo.
- Notas opcionales.
- Mensajes de error legibles sin perder la información capturada.
- Búsqueda y lista desplazable.
- Acción de corrección disponible solo para movimientos reversibles.

### Historial en la ficha del producto

- Orden descendente por fecha.
- Búsqueda local.
- Área desplazable para evitar crecimiento ilimitado de la pantalla.
- La fecha de agotamiento se deriva del historial cuando el stock llega a cero.

### Auditoría

- Búsqueda por tabla, recurso, operación, campo, valor, actor o dispositivo.
- Filtro por intervalo de fechas.
- Consolidación de campos pertenecientes a una misma acción.
- Etiquetas humanas como SKU o nombre de categoría.
- Enlace al recurso cuando exista una ruta interna.

## 9. Decisiones aprobadas para inventario avanzado

Las siguientes reglas están aprobadas como alcance obligatorio, pero todavía no
se consideran implementadas salvo donde este documento lo indique expresamente.

### 9.1 Stock negativo

Se permite que una salida produzca stock negativo. La operación no se descarta
ni se oculta: la interfaz debe mostrar una alerta visible y permitir localizar
los productos, bodegas y documentos responsables del faltante.

### 9.2 Bodegas y ubicaciones

El inventario se administrará por bodega y, opcionalmente, por ubicación dentro
de la bodega. El stock global será la suma de existencias físicas por ubicación.
Todo movimiento deberá identificar bodega de origen o destino según corresponda.

### 9.3 Reservas para pedidos

Se distinguirán tres cantidades:

```text
stock físico
stock reservado
stock disponible = stock físico - stock reservado
```

- Crear o confirmar un pedido reserva unidades, pero no reduce el stock físico.
- Anular un pedido libera la reserva completa.
- Confirmar la venta libera la reserva y crea la salida física `SALE` dentro de
  la misma transacción.
- Si una venta ya confirmada se anula, se genera `RETURN` o `REVERSAL` según la
  mercancía haya regresado o la salida haya sido un error.

### 9.4 Transferencias entre bodegas

Se permiten transferencias mediante un documento con estados:

```text
BORRADOR → DESPACHADA → EN_TRANSITO → RECIBIDA
```

El despacho crea `TRANSFER_OUT` y la recepción crea `TRANSFER_IN`. Una
transferencia inmediata debe guardar salida, entrada, documento y auditoría de
forma atómica. Una transferencia en tránsito conserva trazabilidad de las
unidades pendientes de recepción.

### 9.5 Conteos físicos y conciliación

Existirá una pantalla específica de conteos físicos con documentos persistentes
y hojas imprimibles. El flujo será:

1. Crear un documento para una bodega o conjunto de ubicaciones.
2. Generar una hoja con SKU, producto, ubicación y espacio para cantidad.
3. Permitir conteo ciego, ocultando la existencia esperada.
4. Capturar cantidades contadas y mostrar diferencias.
5. Solicitar revisión y justificación.
6. Confirmar la conciliación.
7. Crear movimientos `ADJUSTMENT` positivos o negativos.
8. Conservar documento, responsable, fechas y auditoría.

La conciliación nunca sobrescribe directamente el stock.

### 9.6 Operación sin conexión

Se permitirá trabajar sin conexión mediante una cola local. Cada comando tendrá
un identificador idempotente para que un reintento no duplique ventas, compras,
reservas ni movimientos. La interfaz distinguirá operaciones pendientes,
sincronizadas y en conflicto.

Al reconectar se compararán versiones y se conservará información suficiente
para resolver conflictos. Como el stock negativo está permitido, una venta
offline válida puede sincronizarse aunque otra estación haya consumido las
existencias; el resultado negativo debe generar una alerta.

### 9.7 Integración transaccional con Ventas y Compras

Confirmar un documento comercial y registrar su impacto en inventario será una
operación atómica de PostgreSQL: todas las acciones se confirman o todas se
revierten.

Una venta confirmada debe guardar conjuntamente el estado del documento, sus
líneas, la liberación de reservas, el movimiento `SALE`, la actualización del
stock por bodega y la auditoría. Una recepción de compra debe guardar el
documento recibido, el movimiento `PURCHASE`, las cantidades recibidas y
pendientes, el aumento de stock y la auditoría.

Ningún módulo comercial modificará directamente el stock. Ventas y Compras
invocarán comandos públicos de Inventario respaldados por funciones
transaccionales de PostgreSQL.

## 10. Deuda técnica

- `InventoryApi` expone las consultas compartidas; sus comandos de escritura
  continúan internos y deberán publicarse antes de integrar Ventas o Compras.
- Las API públicas exponen temporalmente entidades del dominio como modelos
  estables y podrán incorporar DTO propios si los contratos evolucionan.
- Deben añadirse pruebas de repositorio, triggers, reversión y errores de
  concurrencia además de las pruebas actuales de signo de cantidades.
- Faltan los modelos persistentes de bodegas, ubicaciones, reservas,
  transferencias, conteos físicos, cola offline e idempotencia.
