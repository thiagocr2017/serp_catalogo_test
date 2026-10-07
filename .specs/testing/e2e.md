# Pruebas End-to-End

## Enfoque

La suite crece por flujos verticales y por modulo, no con una mega-prueba que
recorra toda la aplicacion en cada cambio. Cada caso usa la app Flutter real,
servicios locales y persistencia real; simula acciones de usuario y verifica
sus resultados consultando el backend.

Un flujo E2E puede atravesar varios modulos cuando el trabajo del usuario lo
requiere. Por ejemplo, una devolucion conecta Ventas, Inventario y Pagos. El
nombre del modulo indica el flujo bajo prueba, no una frontera artificial de
ejecucion.

## Capas de cobertura

- Unit/widget: reglas puntuales, estados, validaciones y presentacion.
- Integracion de modulo: contratos entre componentes del modulo y servicios.
- E2E: navegacion, interaccion de la app, RPC/servicios reales y persistencia.
- pgTAP/concurrencia: restricciones, grants/RLS, atomicidad, rollback,
  idempotencia y carreras entre sesiones.

E2E complementa esas capas; no las reemplaza. Los errores transitorios de
animacion o timing no deben usarse como evidencia de integridad de base de
datos.

## Primer modulo: Productos

Archivo: `integration_test/product_lifecycle_flow_test.dart`.

El test usa la configuracion normal de la app y falla antes de escribir si
`SUPABASE_URL` no apunta a `localhost`, `127.0.0.1` o `::1`. El usuario abre
Nuevo producto, completa datos comerciales y selecciona una categoria y una
presentacion existentes, define stock inicial, guarda, busca el producto,
abre su perfil, lo edita y guarda. La app crea y edita por sus RPC reales; el
test consulta la base para comprobar nombre, precio, estado y stock.

Tambien verifica que el stock inicial produjo exactamente un movimiento y que
editar el producto no duplico ese movimiento. No se desactiva ni borra el
producto porque el historial de inventario es inmutable.

Cada ejecucion deja un producto sintetico con SKU unico y su movimiento local.
No borra datos ni resetea la base. Ejecutar solo sobre Supabase local, nunca
contra un proyecto remoto o produccion.

## Segundo modulo: Inventario

Archivo: `integration_test/inventory_adjustment_flow_test.dart`.

El test requiere un producto activo (el E2E de Productos deja uno) y usa la
bodega/ubicacion predeterminadas existentes. Desde Inventario > Movimientos,
abre Nuevo documento, registra un ajuste positivo de dos unidades y confirma.
Verifica el detalle, documento, linea, movimiento y saldo real en Supabase, y
regresa a la lista de documentos desde el detalle.

Cada corrida agrega dos unidades y un documento/movimiento con referencia E2E
unica. No resetea ni revierte datos, porque el libro de inventario es inmutable.
Para repetir, se puede usar el mismo producto: cada ajuste se registra aparte.

## Inventario: Traslado diferido

Archivo: `integration_test/inventory_transfer_flow_test.dart`.

Estado: paso en macOS contra Supabase local el 2026-10-06. Una primera corrida
completo y persistio las transiciones, pero fallo una asercion visual redundante
al volver a buscar un elemento lazy de la lista; se retiro esa asercion y la
segunda corrida paso completa.

El caso requiere un producto activo con stock en una ubicacion vendible y otra
ubicacion vendible activa en la misma bodega. Desde el formulario real crea un
borrador, vuelve a la lista y recorre Despachar, Marcar en transito y Registrar
recepcion. Comprueba que el borrador no crea movimientos, el despacho registra
una sola salida, la recepcion registra una sola entrada y los saldos de ambas
ubicaciones cambian en la cantidad esperada. Tambien abre el detalle inicial y
vuelve al indice; el estado final y los movimientos se verifican directamente
en Supabase.

Si falta otro destino vendible, el caso crea por la UI una ubicacion estable
`E2E-TRANSFER-DEST` y la reutiliza en corridas siguientes. El caso no resetea ni
revierte la base. Cada traslado conserva stock total y deja un documento
historico. Las dos corridas de verificacion dejaron `TRA-00000030` y
`TRA-00000031`, ambos `RECIBIDA`, con una salida `-1` y una entrada `+1`. No
debe escoger una ubicacion de cuarentena como origen ni destino.

```bash
flutter test integration_test/inventory_transfer_flow_test.dart -d macos
```

## Tercer modulo: Ventas (Clientes)

Archivo: `integration_test/sales_customer_lifecycle_flow_test.dart`.

El caso abre Clientes desde el menu lateral, crea un cliente contado con los
datos minimos, lo encuentra en la lista, entra al perfil, edita el nombre de
fantasia y verifica los campos antes y despues por id en Supabase local. Usa la
UI/API/RPC real y falla antes de escribir si el backend no es loopback.

Cada ejecucion deja un cliente sintetico activo, con telefono, direccion y
agrupacion comercial unicos; no lo elimina ni reinicia la base. El caso prueba
crear, leer y actualizar; desactivacion sigue cubierta por las pruebas propias
del formulario y no se ejecuta para conservar visible el fixture de regresion.

```bash
flutter test integration_test/sales_customer_lifecycle_flow_test.dart -d macos
```

## Ventas: Cotizaciones

Archivo: `integration_test/sales_quote_lifecycle_flow_test.dart`.

Abre Cotizaciones desde el menu, crea un borrador con cliente/producto activos,
comprueba cabecera y snapshot de linea en Supabase, abre el documento desde la
lista, edita las notas, verifica el borrador actualizado y lo marca como
enviado. La comprobacion confirma tambien la moneda/tasa de compatibilidad y
que al salir de borrador ya no se ofrezca edicion.

Este caso requiere clientes y productos E2E existentes; ejecutar primero
`sales_customer_lifecycle_flow_test.dart` y
`product_lifecycle_flow_test.dart`. Cada corrida deja una cotizacion enviada y
no la borra ni revierte. La aceptacion no forma parte de este caso porque la UI
actual cambia el estado pero aun no ofrece elegir el documento siguiente
(pedido/hoja de bodega o factura borrador), segun el requisito de detalle.

```bash
flutter test integration_test/sales_quote_lifecycle_flow_test.dart -d macos
```

## Ventas: Facturas

Archivo: `integration_test/sales_invoice_lifecycle_flow_test.dart`.

Usa un cliente E2E activo y elige un producto con cantidad minima vendible
disponible en una bodega. Desde Facturas abre el formulario, selecciona cliente,
producto y bodega (sin elegir ubicacion), guarda y verifica factura confirmada,
documento `SALE_DISPATCH`, movimientos `SALE` y saldo descontado exactamente.
Abre la factura desde la lista, entra al perfil del cliente y regresa al mismo
detalle y al indice.

Requiere correr antes `sales_customer_lifecycle_flow_test.dart` y el E2E de
Productos; para reponer un fixture de inventario tras varias corridas, ejecutar
el E2E de Productos y luego el de Inventario. Cada ejecucion deja una factura
confirmada y consume unidades reales del stock local; no cancela ni borra el
historial.

```bash
flutter test integration_test/sales_invoice_lifecycle_flow_test.dart -d macos
```

## Ventas: Pedidos

Archivo: `integration_test/sales_order_lifecycle_flow_test.dart`.

Selecciona cliente, producto, bodega y ubicacion. Si falta saldo, lo prepara
con un ajuste confirmado por la UI de Inventario. Verifica que el RPC actual
crea el pedido como `CONFIRMED`, una linea, el documento `SALE_DISPATCH`, el
movimiento `SALE` y el saldo exacto. El pedido aparece en la lista, que hoy no
ofrece ruta ni accion para abrir su detalle.

El RPC llamado historicamente `create_order_with_reservation` actualmente
confirma y descuenta inventario; no reserva stock ni crea borrador. Cada
ejecucion conserva pedido y movimientos. Requiere cliente y producto E2E; si
no hay stock suficiente, el ajuste se registra por la UI y tambien permanece.

```bash
flutter test integration_test/sales_order_lifecycle_flow_test.dart -d macos
```

## Ventas: Consignaciones

Archivo: `integration_test/sales_consignment_lifecycle_flow_test.dart`.

Selecciona cliente, producto con stock vendible, bodega y ubicacion; crea el
documento desde la UI y verifica estado `SENT`, linea, documento de inventario,
movimiento de salida y saldo. Abre el detalle, comprueba el producto y vuelve
al indice. El datasource conserva ahora las lineas anidadas de la consulta.

Cada corrida consume stock y deja el documento como historial. Ejecutar antes
Clientes y Productos, y asegurar saldo disponible; repetir Productos crea un
fixture nuevo por medio del formulario real.

```bash
flutter test integration_test/sales_consignment_lifecycle_flow_test.dart -d macos
```

## Ventas: Devoluciones

Prueba negativa: `integration_test/sales_return_lifecycle_flow_test.dart`.

El caso abre una factura E2E confirmada sin devoluciones, inicia la captura
desde su detalle y trata de confirmar una linea completa. La UI alcanza la RPC
atomica, pero el backend deniega la llamada del rol `anon` (`permission denied
for function sales_confirm_return`); se verifica que no se cree devolucion ni
cambie el saldo. Esta es una prueba E2E de rechazo seguro, no un flujo de
exito.

La migracion concede la RPC a `authenticated`, pero la app actual inicia como
`anon` y no ofrece autenticacion. No ampliar el grant a `anon` para acomodar el
test: primero definir y completar el inicio de sesion/autorizacion para esta
operacion sensible. El exito de la devolucion seguira pendiente hasta entonces.

```bash
flutter test integration_test/sales_return_lifecycle_flow_test.dart -d macos
```

Prueba exitosa autenticada: `integration_test/sales_return_authorized_lifecycle_flow_test.dart`.

El caso crea una cuenta local aleatoria con Supabase Auth, comprueba que la
sesion no sea anonima y recorre desde la UI la devolucion de una linea completa
de una factura E2E elegible. Verifica la devolucion confirmada, la linea ligada
a la factura, el documento `CUSTOMER_RETURN`, el movimiento `RETURN` y el
incremento exacto del saldo en el destino vendible persistido. La sesion se
cierra al terminar; la cuenta aleatoria de Auth permanece en Supabase local.
El flujo no amplia grants ni prueba una pantalla de inicio de sesion de la app,
que aun no existe. Para repetirlo se necesita otra factura E2E sin devolucion.

```bash
flutter test integration_test/sales_return_authorized_lifecycle_flow_test.dart -d macos
```

```bash
flutter test integration_test/inventory_adjustment_flow_test.dart -d macos
```

## Ejecutar

1. Iniciar Supabase local y aplicar migraciones vigentes.
2. Confirmar que exista al menos una categoria activa y una presentacion de
   venta activa. No se requiere catalogo previo de productos.
3. Ejecutar desde la raiz:

   ```bash
   flutter test integration_test/product_lifecycle_flow_test.dart -d macos
   ```

La ejecucion requiere macOS desktop, plugins de Flutter operativos y acceso a
Supabase local. La prueba no invoca `supabase db reset`, porque eso destruiria
datos locales ajenos al caso.

## Ampliacion

Orden acordado para ampliar progresivamente: Productos, Inventario, Ventas,
Pagos y Configuracion. Los flujos cruzan otros modulos cuando el proceso real
lo requiere; Productos crea stock inicial mediante Inventario, por ejemplo.
El traslado diferido ya tiene caso E2E, pendiente de ejecucion contra servicios
locales. Despues seguir con Pagos y Configuracion y ampliar documentos de
Ventas con ciclos aun no cubiertos (aceptacion de cotizacion, autorizacion para
devolucion y siguientes documentos). Configuracion se cubre como flujo de
mantenimiento y prerequisito de modulos consumidores.

La devolucion E2E sigue pendiente de completar un flujo exitoso con sesion
autorizada. El caso actual valida rechazo seguro cuando la app no tiene una
sesion autenticada; no se debe ampliar el grant a `anon` para acomodar el test.

Agregar un caso vertical por comportamiento valioso. Cada caso debe:

- declarar el modulo de entrada y los modulos cruzados;
- crear fixtures mediante RPCs reales cuando sea posible;
- usar claves/command ids unicos y comprobar la persistencia posterior;
- dejar inventario/finanzas en un estado conocido y evitar cleanup destructivo;
- fallar cerrado si el backend no es local;
- mantener las propiedades de atomicidad y concurrency en pgTAP, no inferirlas
  a partir de que la UI haya mostrado exito.
