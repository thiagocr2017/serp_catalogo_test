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

## Inventario de escrituras directas y sustitutos previstos

| Propietario | Escritura actual | Ubicacion | Sustituto del Bloque 1B |
|---|---|---|---|
| Productos | Actualizar producto, desactivar producto, crear/editar categoria y completar campos visuales despues de crear producto | `SupabaseProductDataSource` | RPC de comandos de Producto y Categoria; la creacion con stock inicial sera una unica transaccion sin `UPDATE` posterior directo. |
| Productos | Activar promociones y actualizar condiciones individuales | `SupabasePromotionRepository` | Ampliar el comando atomico de promociones o crear comandos de intencion concretos. |
| Configuracion | Guardar empresa, preferencias, logo y presentaciones; inicializar superadministrador por dispositivo | `SupabaseConfigurationRepository` | RPC de Configuracion; retirar la inicializacion de superadministrador del cliente. |
| Ventas | Crear, editar y desactivar agentes; limpiar seleccion de catalogo en Configuracion | `SupabaseSalesDataSource` | Comandos de Ventas y `ConfigurationApi.clearSelectedCatalogAgent`. |
| Inventario | Crear y editar bodegas/ubicaciones; movimientos y reversiones directos heredados | `SupabaseInventoryDataSource` | Comandos de Inventario para estructura fisica; retirar caminos directos de movimientos. |
| Inventario | Confirmar documentos | `create_and_confirm_inventory_document` | Conservar como comando documental, proteger estados y resolver idempotencia concurrente. |

## RPC y privilegios actuales

- `create_product_with_initial_stock`, `save_bulk_promotion`,
  `create_and_confirm_inventory_document`, `record_inventory_transaction` y
  `reverse_inventory_transaction` son ejecutables por `anon` y
  `authenticated`.
- Las tablas de Productos, Categorias, Promociones, Configuracion, Bodegas,
  Ubicaciones y Documentos mantienen politicas locales abiertas de lectura y/o
  escritura.
- `inventory_balances` ya revoca `INSERT`, `UPDATE` y `DELETE` para los roles
  de aplicacion; los demas saldos deben continuar siendo derivados de
  movimientos.
- `purge_test_data_and_go_production` no se utilizara desde el cliente
  ordinario en el Bloque 1B. Su sustitucion administrativa local se definira y
  verificara antes de revocar el acceso actual.

## Storage actual

- `product-images` y `catalog-assets` son buckets publicos con limite de 5 MB
  y MIME permitidos JPEG, PNG y WebP.
- Las politicas locales permiten a `anon` y `authenticated` insertar,
  actualizar y eliminar cualquier objeto del bucket correspondiente.
- No se modificara Storage en el Bloque 1A. El Bloque 1B debera inventariar
  consumidores y crear sustitutos antes de endurecer esas politicas.

## Contratos publicos propuestos para Bloque 1B

- `ProductApi`: consultas minimas para Inventario y comandos de producto y
  categoria sin exponer repositorios ni tablas.
- `ConfigurationApi`: consultas comerciales y comando
  `clearSelectedCatalogAgent`; no exportara providers de infraestructura.
- `InventoryApi`: consultas, comandos documentales y comandos de bodega/
  ubicacion; no movimientos directos.
- `SalesApi`: agentes y comandos propios; solicitara cambios de Configuracion
  mediante su API publica.
- Todos los comandos recibiran un contexto neutral de trazabilidad, preparado
  para la futura identidad y autorizacion sin acoplamiento a Supabase Auth.

## Fuera de alcance

Reservas, cola offline, conteos, transito, traslados inteligentes, outbox,
impresion fisica, Autenticacion y el endurecimiento final de Storage no forman
parte del Bloque 1A.
