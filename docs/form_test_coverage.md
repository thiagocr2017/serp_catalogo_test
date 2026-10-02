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
| Productos | Producto crear/editar | CRU + validación | `product_form_validation_test.dart` | Parcial: valida bloqueo inválido; faltan carga/actualización válida y tipos por campo completos. |
| Productos | Categorías | CRUD físico/reasignación | `category_form_validation_test.dart` | Cubierto inicialmente: create inválido/válido, read, update y delete vacío. |
| Productos | Promociones masivas | CRU + activar/desactivar | `promotion_form_validation_test.dart` | Parcial: create válido e inválido; faltan read/update, alcance categoría/manual y activar/desactivar. |
| Productos | Catálogo PDF | Operación específica | `catalog_pdf_service_test.dart` | Parcial por servicio; falta prueba UI de selección, orden, colores y persistencia. |
| Productos | Importar/exportar productos | Operación específica | `bulk_product_transfer_service_test.dart` | Parcial por servicio; falta prueba UI de selección CSV/ZIP y bloqueo por errores. |
| Inventario | Bodegas | CRU actual | `warehouses_form_validation_test.dart` | Parcial: create válido/inválido; faltan read/update. |
| Inventario | Ubicaciones | CRU actual | Pendiente | Falta prueba UI. |
| Inventario | Documento de inventario | Confirmar documento | Pendiente | Bloqueado hasta estabilizar pantalla/autocomplete de documentos. |
| Inventario | Conteos físicos | Operación específica | Pendiente | Pantalla aún en desarrollo. |
| Configuración | Empresa/impuestos | Update/configurar | `settings_form_validation_test.dart` | Parcial: guarda válido y rechaza decimal no normalizado; faltan más tipos/rangos. |
| Configuración | Presentaciones | CRU actual | `settings_form_validation_test.dart` | Parcial: create inválido/válido; faltan read/update. |
| Configuración | Logo | Operación específica | Pendiente | Falta prueba de selección/reemplazo de imagen. |
| Configuración | Purga de prueba a producción | Operación destructiva | Pendiente | Falta prueba de confirmación y bloqueo por texto incorrecto. |
| Ventas | Agentes | CRUD lógico | `agent_form_validation_test.dart` | Parcial: create inválido/válido; faltan read/update/activar/desactivar. |
| Ventas | Clientes | CRUD lógico + contactos | `customers_form_validation_test.dart` | Parcial: create inválido/válido y validaciones; faltan read/update/desactivar. |
| Ventas | Cotizaciones | Operación/documento | Pendiente | La pantalla actual es lista de solo lectura. |
| Ventas | Pedidos | Operación/documento | Pendiente | La pantalla actual es lista de solo lectura. |
| Ventas | Facturas | Operación/documento | Pendiente | La pantalla actual es lista de solo lectura. |
| Ventas | Devoluciones | Operación/documento | Pendiente | La pantalla actual es lista de solo lectura. |
| Ventas | Consignaciones | Operación/documento | Pendiente | La pantalla actual es lista de solo lectura. |
| Pagos | Pagos y recibos | Operación/documento | Pendiente | El módulo todavía no tiene formularios completos. |

## Regla de avance

Cuando se implemente o modifique un formulario:

1. Actualizar esta tabla.
2. Crear o actualizar su prueba en `test/`.
3. Registrar la cobertura en el SDD del módulo si cambia el alcance.
4. No marcar la tarea como completada si la prueba de operaciones reales y la
   prueba de validación no existen o no pasan.
