# Hoja de ruta: módulos funcionales y comprobados

Fecha: 2026-10-06
Estado: ejecución por capacidades; baseline validada, Inventario en curso.

## Objetivo

Dejar cada capacidad actualmente expuesta en la aplicación utilizable de punta
a punta y con pruebas que demuestren sus resultados. Una pantalla dibujada o
un método RPC presente no cuenta por sí solo como función comprobada.

## Definición de comprobado

Una capacidad se marca **completa** solo cuando cumple todo lo aplicable:

1. Tiene entrada visible en navegación o un enlace contextual probado.
2. Cubre carga, vacío, error y validación de UI pertinentes.
3. La operación válida llega por la API pública hasta persistencia, y su
   resultado se puede volver a leer.
4. PostgreSQL prueba reglas, permisos, atomicidad e idempotencia cuando hay
   escritura persistente.
5. La spec y `.specs/testing/form-coverage.md` reflejan exactamente la
   cobertura existente.
6. `flutter analyze`, `flutter test`, `supabase test db` y build desktop pasan
   al cerrar el conjunto de cambios correspondiente.

Mock/fake UI demuestra contrato y navegación, no persistencia. Una prueba RPC
por sí sola tampoco demuestra el recorrido desde la aplicación; se requieren
ambas capas para escrituras críticas.

## Baseline 2026-10-06

| Verificación | Resultado |
|---|---|
| `flutter analyze --no-pub` | PASS, sin hallazgos |
| `flutter test --no-pub` | PASS, 198 pruebas |
| `supabase test db` | PASS, 20 archivos / 421 aserciones |
| `flutter build macos --debug` | PASS, `build/macos/Build/Products/Debug/serp.app` |

Los avisos de fuentes PDF para el símbolo `₡` aparecieron durante las pruebas
del renderer. No hicieron fallar la suite, pero deben verificarse en el bloque
de documentos antes de dar por comprobadas las salidas localizadas.

## Alcance y orden

### 0. Línea base

- [x] Ejecutar análisis estático, suite Flutter y pgTAP completos.
- [x] Ejecutar build macOS y registrar salida reproducible.

### 1. Productos

Capacidades: productos, categorías, promociones, precio/presentaciones,
catálogo e importar/exportar.

- [x] Formularios CRUD de producto, categoría y promoción con pruebas de UI.
- [ ] Probar persistencia real desde repositorio hasta PostgreSQL para cada
  operación pública y lectura posterior.
- [ ] Probar pantalla de catálogo e importar/exportar; servicio probado no
  sustituye interacción de pantalla.
- [ ] Cerrar conversión de presentación a unidades base y comportamiento de
  promociones en documentos comerciales con pgTAP y pruebas de integración.

### 2. Inventario

Capacidades: bodegas/ubicaciones, ajustes, traslados, saldos, documentos,
auditoría, reservas y conteos.

- [x] Bodegas: crear/leer/editar probado en UI.
- [ ] Ubicaciones: agregar creación de UI al CRUD cubierto parcialmente.
- [x] Documento: probar validación sin producto y confirmación de ajuste,
  payload y navegación a detalle en UI.
- [ ] Verificar desde UI el guardado de un borrador de traslado y su apertura
  desde la lista.
- [x] Unificar el despacho para que siempre genere `TRANSFER_OUT` y avance el
  estado atómicamente; añadir retry seguro y pgTAP.
- [x] Cubrir tránsito/recepción desde UI, error recuperable y reintentos
  idempotentes con pgTAP; recepción actualiza el saldo destino atómicamente.
- [ ] Verificar lectura posterior desde PostgREST en una prueba de integración
  reproducible de la aplicación.
- [ ] Conteos físicos: completar flujo persistente o retirar del menú hasta
  contar con especificación, interfaz operativa y pruebas.
- [ ] Reversión, reservas, transferencias diferidas y stock disponible deben
  tener cobertura concurrente/pgTAP antes de exponerlas como garantía.
- [ ] Verificar A4, ticket 80 mm y ESC/POS con caracteres de la moneda
  configurada.

### 3. Configuración

Capacidades: empresa, impuestos, moneda, presentación, transportes, geografía,
identificación, logo y puerta de entorno.

- [x] Empresa/impuestos y presentaciones tienen pruebas de formulario.
- [ ] Crear/editar/desactivar los catálogos restantes desde UI y comprobar
  recarga luego de guardar.
- [ ] Probar carga/reemplazo de logo y validaciones de archivo.
- [ ] Probar que la purga de datos demo exige confirmación correcta y que el
  bloqueo se mantiene ante texto inválido.
- [ ] Comprobar que moneda y símbolo configurados se reflejan en listas,
  detalles, cálculos e impresión, sin tasas de cambio fuera de Payments.

### 4. Ventas

Capacidades actuales declaradas: agentes, clientes, cotizaciones, pedidos,
facturas, devoluciones y consignaciones.

- [x] Agentes y clientes CRUD tienen cobertura UI de operación principal.
- [x] Cotizacion: alta/edicion, listas/busqueda, detalle, acciones de estado y
  retorno contextual tienen pantallas y pruebas de UI; las reglas de
  presentacion/descuentos tienen pgTAP.
- [x] Pedidos, facturas y consignaciones: listas y captura estan conectadas a
  APIs; factura exige bodega y pgTAP verifica asignacion atomica de ubicaciones.
- [x] Facturas abren detalle con cliente, y el acceso a devolución conserva
  el contexto. Crear devoluciones queda bloqueado en UI y API hasta completar
  su RPC atomica; no se invoca la RPC heredada.
- [ ] Pedidos y facturas: demostrar create/load/confirm/cancel y efectos de
  inventario desde una prueba de integracion reproducible de la app y precisar
  las transiciones disponibles.
- [ ] Devoluciones: mantener confirmación bloqueada hasta completar la
  cuarentena persistida de Inventory, settlement público de Payments y RPC
  transaccional idempotente de Sales, con bloqueo/concurrencia pgTAP.
- [ ] Consignaciones: no implementar liquidación antes de cerrar estados,
  titularidad, liquidación parcial, diferencias y devoluciones; hasta entonces
  mostrar solo las operaciones realmente disponibles.
- [ ] Enlaces y listas por cliente deben abrir el documento correcto, mostrar
  su estado real y conservar regreso contextual.

### 5. Payments

- [x] RPC y esquema base existen; 402 aserciones DB de la suite pasan.
- [ ] Agregar flujos UI para pagos, confirmación/anulación, gastos,
  transferencias, cuentas y métodos; probar validación y estados.
- [ ] En prueba de integración de aplicación, crear y releer pago y demostrar
  conciliación/aplicación contra factura.
- [ ] Completar recibo, reembolso y crédito con idempotencia y referencias
  comerciales antes de usarlos desde devoluciones.
- [ ] Definir y probar roles antes de producción; ver
  `.specs/modules/authorization/production-gate.md`.

### 6. Autorización y salida a producción

- [ ] No figura como módulo funcional implementado. Antes de producción,
  completar autenticación, permisos por RPC, actor autenticado, aislamiento de
  empresa, Storage y pruebas negativas. Mantener activa la puerta de producción.

## Secuencia inmediata

1. Cerrar el formulario de documentos de Inventory: UI (iniciado), integración
   persistente y pruebas de traslados/borradores.
2. Terminar operaciones públicas actuales de Inventory y Productos, luego
   Configuración; son dependencias para documentos comerciales.
3. Verificar ciclos de cotización, pedido y factura junto con Payments.
4. Diseñar e implementar devolución atómica y consignación únicamente cuando
   sus contratos de módulo y pgTAP estén completos.
5. Cerrar build, regresión completa y puerta de producción.

## Registro de ejecución

### 2026-10-06 - Inventory: formulario de documento

- Añadidas pruebas de UI para rechazar una línea sin producto sin llamar la API,
  y crear un ajuste con línea válida enviando bodega, ubicación y cantidad,
  luego navegando al detalle.
- Prueba: `test/modules/inventory/presentation/inventory_document_form_page_test.dart`.
- Resultado: 2/2 pasan.
- Pendiente: persistencia con Supabase real, traslados y flujo de borrador.

### 2026-10-06 - Inventory: ciclo seguro de traslado

- Hallazgo: la lista ofrecía dos acciones para un borrador. `dispatch_transfer`
  solo cambiaba estado y podía dejar existencias sin descontar.
- La lista ofrece `Despachar traslado`, `Marcar en tránsito` y `Registrar
  recepción` según estado. Cada RPC bloquea la fila y valida tipo/estado; los
  reintentos ya completados son éxito idempotente. Recepción agrega `TRANSFER_IN`
  por línea y actualiza el saldo destino en la misma transacción.
- El test de UI cubre despacho único, error sin transición, reintento a tránsito
  y recepción. pgTAP verifica los estados, saldos y ausencia de movimientos
  duplicados.
- Migración incremental local aplicada; `supabase test db`: 20 archivos / 421
  aserciones PASS. `flutter analyze --no-pub`: limpio. Suite Flutter completa y
  build macOS debug en curso al registrar este avance.
- Pendiente: lectura posterior desde PostgREST en prueba de integración
  reproducible; también queda por verificar UI de guardado/apertura de borrador
  de traslado.

### 2026-10-06 - Ventas: operaciones comerciales y retornos seguros

- Añadidas rutas de listas, busqueda, detalle y formularios operativos para
  cotizaciones, pedidos, facturas y consignaciones; el perfil de cliente enlaza
  a documentos y conserva el contexto de retorno.
- La factura crea despacho atómico en la bodega seleccionada, distribuyendo
  cantidades entre ubicaciones con stock. Migraciones y pgTAP verifican
  vínculo de cliente, stock agregado y cancelación ante devoluciones legacy.
- Las devoluciones existentes se pueden consultar. La creación nueva está
  expresamente bloqueada en UI y la fuente de datos rechaza antes de RPC hasta
  que Sales/Inventory/Payments implementen y prueben el contrato transaccional.
- `flutter analyze --no-pub`: PASS; `flutter test --no-pub`: 198; `supabase
  test db`: 20 archivos / 421; `flutter build macos --debug`: PASS.
- Pendiente: prueba reproducible de recorrido UI/API/PostgREST, ampliar payloads
  válidos/negativos de pedidos y consignaciones, y completar devoluciones antes
  de habilitar su captura.
