# Bloque 1A Base de caracterizacion y fronteras

## Alcance

Este documento registra la linea base aprobada antes del Bloque 1B. No cambia
permisos, migraciones, RPC, repositorios ni contratos productivos.

## Punto de restauracion

- Etiqueta: `restore/pre-inventory-foundations`.
- Commit apuntado: `4ee008b docs: require direct ESC POS printing and secure module contracts`.
- Cambios ajenos preservados: `SDD_Modulo_Ventas.md`, `assets/`,
  `supabase/snippets/` e `indicaciones para modulo inventario.rtf`.

## Comportamiento caracterizado

- Las ventas y salidas de traslado normalizan cantidades negativas.
- Compras, devoluciones y apertura normalizan cantidades positivas.
- Los ajustes conservan el signo indicado.
- Un comando documental conserva la clave de idempotencia y las cantidades de
  sus lineas.
- El modelo de documento conserva numero, estado, ubicaciones, lineas y datos
  historicos actualmente expuestos por la aplicacion.

Estas pruebas describen el comportamiento Dart actual. No reemplazan las
pruebas PostgreSQL de permisos, atomicidad e idempotencia concurrente previstas
para el Bloque 1B.

## Matriz de operaciones reales

| Propietario | Método Dart | Archivo | Tabla/bucket/RPC | Operación | Política o privilegio actual | Consumidor | Sustituto | Bloque |
|---|---|---|---|---|---|---|---|---|
| Productos | `getProducts`, `getProductById` | `SupabaseProductDataSource` | `product_catalog` | SELECT | SELECT para `anon`, `authenticated` | Productos, Catálogo | Consulta pública de Producto | 1C |
| Productos | `createProduct` | `SupabaseProductDataSource` | `create_product_with_initial_stock`, luego `products` | RPC, UPDATE directo | EXECUTE y UPDATE locales abiertos | Formulario Producto | Un comando único que incluya stock e imagen/presentación | 1C |
| Productos | `updateProduct`, `deactivateProduct` | `SupabaseProductDataSource` | `products` | UPDATE | RLS `using (true)` y UPDATE para roles locales | Formulario/Ficha Producto | RPC de Producto | 1C |
| Categorías | `getCategories` | `SupabaseProductDataSource` | `categories` | SELECT | RLS local abierta y SELECT | Productos | Consulta pública de Producto | 1C |
| Categorías | `createCategory`, `updateCategory` | `SupabaseProductDataSource` | `categories` | INSERT, UPDATE | RLS local abierta y DML | Página Categorías | RPC de Categoría | 1C |
| Categorías | `deleteCategory` | `SupabaseProductDataSource` | `delete_category_and_reassign_products` | RPC | SECURITY DEFINER; EXECUTE local | Página Categorías | Conservar y endurecer contrato | 1C |
| Promociones | `getPromotions` | `SupabasePromotionRepository` | promociones y relaciones | SELECT | RLS local abierta y SELECT | Página Promociones | Consulta pública de Producto | 1C |
| Promociones | `createPromotion`, `updatePromotion` | `SupabasePromotionRepository` | `save_bulk_promotion` | RPC | SECURITY INVOKER; EXECUTE local | Página Promociones | Comando atómico existente endurecido | 1C |
| Promociones | `setActive` | `SupabasePromotionRepository` | `bulk_promotions` | UPDATE | RLS local abierta y UPDATE | Página Promociones | Extender comando de promoción | 1C |
| Promociones | `setProductCondition` | `SupabasePromotionRepository` | `bulk_promotion_products` | UPSERT | RLS local abierta y DML | Página Promociones | Extender comando de promoción | 1C |
| Configuración | `get`, `save` | `SupabaseConfigurationRepository` | `app_settings` | SELECT, UPDATE | RLS local abierta y DML | Ajustes y consumidores | Fachada/RPC de Configuración | 1B |
| Configuración | `purgeTestDataAndGoProduction` | `SupabaseConfigurationRepository` | `purge_test_data_and_go_production` | RPC destructiva | SECURITY DEFINER; EXECUTE local | Ajustes | Herramienta administrativa local separada | 1B |
| Configuración | `getCatalogPreferences`, `saveCatalogPreferences`, `setCatalogLogoUrl` | `SupabaseConfigurationRepository` | `app_settings` | SELECT, UPDATE | RLS local abierta y DML | Catálogo, Ajustes | Fachada/RPC de Configuración | 1B |
| Presentaciones | `getPackagingPresentations`, `savePackagingPresentation` | `SupabaseConfigurationRepository` | `packaging_presentations` | SELECT, INSERT, UPDATE | RLS local abierta y DML | Ajustes, Productos | RPC de Configuración | 1B |
| Agentes | `getAgents`, `createAgent`, `updateAgent`, `deactivateAgent` | `SupabaseSalesDataSource` | `catalog_agents` | SELECT, INSERT, UPDATE | RLS local abierta y DML | Ventas, Catálogo | Comandos de Ventas | 1B |
| Agentes/Configuración | `deactivateAgent` | `SupabaseSalesDataSource` | `app_settings` | UPDATE ajeno | RLS local abierta y DML | Ventas | `ConfigurationApi.clearSelectedCatalogAgent` | 1B |
| Bodegas | `getWarehouses`, `saveWarehouse` | `SupabaseInventoryDataSource` | `warehouses` | SELECT, INSERT, UPDATE | RLS local abierta y DML | Inventario | Comando de Bodega | 1D |
| Ubicaciones | `saveLocation` | `SupabaseInventoryDataSource` | `inventory_locations` | INSERT, UPDATE | RLS local abierta y DML | Inventario | Comando de Ubicación | 1D |
| Movimientos | `recordTransaction` | `SupabaseInventoryDataSource` | `record_inventory_transaction` | RPC | SECURITY INVOKER; EXECUTE local | Repositorio heredado | Retirar camino directo | 1D |
| Reversiones | `reverseTransaction` | `SupabaseInventoryDataSource` | `reverse_inventory_transaction` | RPC | SECURITY INVOKER; EXECUTE local | Repositorio heredado | Reversión documental | 1D |
| Documentos | `createAndConfirmDocument` | `SupabaseInventoryDataSource` | `create_and_confirm_inventory_document` | RPC | SECURITY INVOKER; EXECUTE local | Formulario Inventario | Mantener, proteger e idempotencia concurrente | 1D |
| Documentos y líneas | `documents`, `document` | `SupabaseInventoryDataSource` | tablas de documento/líneas | SELECT | RLS local abierta y SELECT | Inventario | Consulta pública de Inventario | 1D |
| Documentos y líneas | escritura directa externa | SQL/RLS | tablas de documento/líneas | INSERT, UPDATE | RLS `using (true)` y DML local | Cualquier cliente local | Revocar tras migrar consumidores | 1D |
| Orden del catálogo | `saveCatalogOrder` | `SupabaseProductDataSource` | `save_catalog_order` | RPC | SECURITY DEFINER; EXECUTE local | Catálogo PDF | Comando de Producto con alcance validado | 1C |
| Imagen de producto | `upload`, `remove`, `getPublicUrl` | `ProductImageService` | `product-images` | Storage | bucket público; CRUD local por bucket | Formulario Producto | Endurecer tras inventario de consumidores | 1C |
| Logo y activos | `uploadCatalogLogo`, `downloadCatalogLogo` | `SupabaseConfigurationRepository` | `catalog-assets` | Storage | bucket público; CRUD local por bucket | Ajustes, Catálogo PDF | Endurecer tras inventario de consumidores | 1B |

## Matriz de RPC actuales

| RPC | Seguridad | `search_path` | Roles con ejecución | Tablas escritas | Idempotencia | Auditoría | Destino |
|---|---|---|---|---|---|---|---|
| `create_product_with_initial_stock` | INVOKER | fijo vacío | `anon`, `authenticated` | `products`, movimientos/documento según migración vigente | No recibe clave externa | Trigger de producto; movimiento/documento según flujo | 1C: comando único sin UPDATE directo posterior |
| `delete_category_and_reassign_products` | DEFINER | fijo vacío | `anon`, `authenticated` | categorías, productos, relaciones de promoción | No | Trigger de productos/categorías | 1C: conservar con validación y permisos mínimos |
| `save_bulk_promotion` | INVOKER | fijo vacío | `anon`, `authenticated` | promoción y relaciones | No | Trigger de promoción | 1C: ampliar para sustituir UPDATE/UPSERT directos |
| `save_catalog_order` | DEFINER | fijo vacío | `anon`, `authenticated` | categorías, productos | No | Triggers de producto/categoría | 1C: alcance validado y privilegios revisados |
| `purge_test_data_and_go_production` | DEFINER | fijo vacío | `anon`, `authenticated` | datos de prueba, Storage, configuración | No | No hay evento de purga dedicado comprobado | 1B: herramienta administrativa local; revocar cliente |
| `record_inventory_transaction` | INVOKER | fijo vacío | `anon`, `authenticated` | movimientos, saldos, productos | Sí, por `command_id` secuencial | Trigger de producto; no evento consolidado de movimiento | 1D: retirar ejecución directa |
| `reverse_inventory_transaction` | INVOKER | fijo vacío | `anon`, `authenticated` | movimientos, saldos, productos | Sí, por `command_id` secuencial | Trigger de producto; no evento consolidado de reversión | 1D: sustituir por reversión documental |
| `create_and_confirm_inventory_document` | INVOKER | fijo vacío | `anon`, `authenticated` | documentos, líneas, movimientos, saldos, productos | Secuencial; conflicto concurrente pendiente | Trigger de documento y de producto | 1D: inmutabilidad e idempotencia concurrente |

## Matriz de Storage actual

| Bucket | Consumidor | Lectura | Inserción | Reemplazo | Eliminación | Riesgo |
|---|---|---|---|---|---|---|
| `product-images` | `ProductImageService` | Pública para roles locales | `anon`/`authenticated` por bucket | UPDATE por bucket | DELETE por bucket | Un cliente local puede operar objetos ajenos del bucket; solo MIME y tamaño limitan la carga. |
| `catalog-assets` | `SupabaseConfigurationRepository` | Pública para roles locales | `anon`/`authenticated` por bucket | UPDATE por bucket | DELETE por bucket | Mismo riesgo; el nombre fijo de logo no limita autorización. |

## Pendientes verificables solo con PostgreSQL en 1D

- Reintento secuencial y concurrente contra `command_id` real.
- Atomicidad de documento, líneas, movimientos, saldos y auditoría ante fallo.
- Rechazo efectivo de DML y RPC heredadas después de la migración.
- Inmutabilidad de documentos/líneas confirmadas y rutas de reversión.
- RLS, `GRANT`, `REVOKE` y comportamiento de Storage con el rol real.

## Contratos públicos propuestos

- `ProductApi`: consultas mínimas para Inventario y comandos de producto y
  categoría sin exponer repositorios ni tablas. Se implementará en 1C.
- `ConfigurationApi`: consultas comerciales y comando
  `clearSelectedCatalogAgent`; no exportará providers de infraestructura. Se
  implementará en 1B.
- `InventoryApi`: consultas, comandos documentales y comandos de bodega/
  ubicación; no movimientos directos. Se implementará en 1D.
- `SalesApi`: agentes y comandos propios; solicitara cambios de Configuracion
  mediante su API publica.
- Todos los comandos recibirán un contexto neutral de trazabilidad, preparado
  para la futura identidad y autorización sin acoplamiento a Supabase Auth.

## Fuera de alcance

Reservas, cola offline, conteos, tránsito, traslados inteligentes, outbox,
impresión física, Autenticación y el endurecimiento final de Storage no forman
parte del Bloque 1A.
