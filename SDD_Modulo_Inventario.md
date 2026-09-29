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

La arquitectura objetivo prohíbe importar providers, controladores o entidades
internas de Productos. La implementación actual todavía presenta estas
dependencias y debe migrarse a contratos dentro de `product/api/`.

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

## 9. Decisiones pendientes

- Permitir o impedir que una salida produzca stock negativo.
- Manejo de bodegas y ubicaciones múltiples.
- Reservas de inventario para pedidos.
- Transferencias entre bodegas.
- Conteos físicos y conciliaciones.
- Operación sin conexión, reintentos y resolución de conflictos.
- Integración transaccional con Ventas y Compras.

## 10. Deuda técnica

- La pantalla de Inventario consume directamente providers y controladores de
  Productos.
- Productos consume providers y entidades internas de Inventario para mostrar
  sus historiales.
- `InventoryApi` expone consultas, pero todavía debe ofrecer los comandos y
  modelos públicos necesarios para eliminar esas dependencias.
- Deben añadirse pruebas de repositorio, triggers, reversión y errores de
  concurrencia además de las pruebas actuales de signo de cantidades.
