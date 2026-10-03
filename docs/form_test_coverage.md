# Cobertura de pruebas de formularios

Este registro complementa `DOCUMENT_STANDARDS.md` y `MODULE_STRUCTURE.md`.
Un formulario sólo puede marcarse como listo cuando tiene pruebas acordes con
su operación real:

- **CRUD**: crear, cargar/leer, actualizar y eliminar/desactivar.
- **CRU**: crear, cargar/leer y actualizar, cuando no existe eliminación.
- **Operación específica**: confirmar, importar, exportar, ordenar, guardar
  configuración, seleccionar, calcular u otra acción para la que fue creado.

Además, todo formulario debe probar validaciones de campos requeridos, tipo de
dato, formato, rangos y que no se ejecuten comandos con datos inválidos.

## Estado actual

| Módulo | Formulario | Operación esperada | Prueba actual | Estado |
|---|---|---:|---|---|
| Productos | Producto crear/editar | CRU + validación | `product_form_validation_test.dart` | **Cubierto para la operación actual**: bloqueo inválido, tipos numéricos, create válido con stock inicial, read/update de producto existente. |
| Productos | Categorías | CRUD físico/reasignación | `category_form_validation_test.dart` | **Cubierto para la operación actual**: create inválido/válido, read, update y delete de categoría vacía. La reasignación de productos en categoría con contenido requiere prueba adicional cuando se estabilice ese flujo. |
| Productos | Promociones masivas | CRU + activar/desactivar | `promotion_form_validation_test.dart` | **Cubierto para la operación actual**: create inválido/válido, read/update, alcance por categoría y activar/desactivar. |
| Productos | Catálogo PDF | Operación específica | `catalog_pdf_service_test.dart` | **No listo como formulario UI**: existe cobertura de servicio; falta prueba de pantalla para selección, orden, colores y persistencia. |
| Productos | Importar/exportar productos | Operación específica | `bulk_product_transfer_service_test.dart` | **No listo como formulario UI**: existe cobertura de servicio; falta prueba de pantalla para selección CSV/ZIP y bloqueo por errores. |
| Inventario | Bodegas | CRU actual | `warehouses_form_validation_test.dart` | **Cubierto para la operación actual**: create inválido/válido, read y update. |
| Inventario | Ubicaciones | CRU actual | `warehouses_form_validation_test.dart` | **Cubierto para la operación actual**: read y update de ubicación existente. Falta create específico de ubicación. |
| Inventario | Documento de inventario | Confirmar documento | Pendiente | **No listo**: bloqueado hasta estabilizar pantalla/autocomplete de documentos en el bloque de Inventario. |
| Inventario | Conteos físicos | Operación específica | Pendiente | **No listo**: pantalla aún en desarrollo. |
| Configuración | Empresa/impuestos | Update/configurar | `settings_form_validation_test.dart` | **Cubierto para la operación actual**: guarda válido por API pública y rechaza decimal no normalizado. |
| Configuración | Presentaciones | CRU actual | `settings_form_validation_test.dart` | **Cubierto para la operación actual**: create inválido/válido, read y update. |
| Configuración | Logo | Operación específica | Pendiente | **No listo**: falta prueba de selección/reemplazo de imagen. |
| Configuración | Purga de prueba a producción | Operación destructiva | Pendiente | **No listo**: falta prueba de confirmación y bloqueo por texto incorrecto. |
| Ventas | Agentes | CRUD lógico | `agent_form_validation_test.dart` | **Cubierto para la operación actual**: create inválido/válido, read, update, activar y desactivar. |
| Ventas | Clientes | CRUD lógico + contactos | `customers_form_validation_test.dart` | **Cubierto para la operación actual**: create inválido/válido, validación de contactos y límite, read/update, guardado de contactos y desactivar. |
| Ventas | Cotizaciones | Operación/documento | Pendiente | **No listo**: la pantalla actual es lista de solo lectura. |
| Ventas | Pedidos | Operación/documento | Pendiente | **No listo**: la pantalla actual es lista de solo lectura. |
| Ventas | Facturas | Operación/documento | Pendiente | **No listo**: la pantalla actual es lista de solo lectura. |
| Ventas | Devoluciones | Operación/documento | Pendiente | **No listo**: la pantalla actual es lista de solo lectura. |
| Ventas | Consignaciones | Operación/documento | Pendiente | **No listo**: la pantalla actual es lista de solo lectura. |
| Pagos | Pagos y recibos | Operación/documento | Pendiente | **No listo**: el módulo todavía no tiene formularios completos. |

## Suite actual verificada

La suite de formularios registrada contiene 21 pruebas de UI y debe ejecutarse
antes de marcar como completa una tarea que toque formularios:

```bash
flutter test \
  test/modules/product/presentation/product_form_validation_test.dart \
  test/modules/product/presentation/category_form_validation_test.dart \
  test/modules/product/presentation/promotion_form_validation_test.dart \
  test/modules/sales/presentation/agent_form_validation_test.dart \
  test/modules/sales/presentation/customers_form_validation_test.dart \
  test/modules/configuration/presentation/settings_form_validation_test.dart \
  test/modules/inventory/presentation/warehouses_form_validation_test.dart
```

## Regla de avance

Cuando se implemente o modifique un formulario:

1. Actualizar esta tabla.
2. Crear o actualizar su prueba en `test/`.
3. Registrar la cobertura en el SDD del módulo si cambia el alcance.
4. No marcar la tarea como completada si la prueba de operaciones reales y la
   prueba de validación no existen o no pasan.
