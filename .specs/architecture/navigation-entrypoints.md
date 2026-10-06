# Navigation Entry Points

## Regla obligatoria

Toda pantalla principal de un modulo funcional debe tener una entrada visible
en el menu lateral del shell de escritorio y navegar a su ruta indice.
Registrar una ruta en GoRouter no la hace accesible por si sola.

## Patrones visuales aprobados

- El grupo expandible `Productos` del menu es el patron de referencia vigente
  para expansion y seleccion de modulos. Los nuevos grupos deben usar el mismo
  `ExpansionTile`, estructura, tema y calculo de rutas registradas; no crear una
  variante de animacion por modulo.
- Los encabezados expandibles usan `splashColor: transparent` y
  `enableFeedback: false`: al expandir o colapsar, el scroll de la lista puede
  desplazar la fila mientras la tinta se anima y dejar una forma transitoria
  sobre filas vecinas. Mantener las animaciones de expansion y seleccion de
  los destinos del menu.
- Una solucion de interaccion ya verificada se conserva como patron. Solo se
  cambia si el usuario pide expresamente unificar o modificar el tema visual.
- La apertura inicial se determina con la misma lista explicita de rutas
  principales que aparece en el registro, no con un prefijo general del modulo.

## Pantallas secundarias

- Un perfil, detalle, alta o edicion no necesita entrada propia si se alcanza
  desde una pantalla principal mediante una accion visible y probada.
- Formularios `new` se abren desde la accion de crear de su lista; no se usan
  como destino del menu lateral.
- El estado seleccionado del menu puede agrupar rutas descendientes, pero al
  pulsar la entrada debe navegar al indice exacto del modulo.
- Colapsar un grupo mientras su ruta descendiente sigue activa debe ocultar
  las entradas sin artefactos visuales ni excepciones de layout. Conservar el
  `ExpansionTile` aprobado y verificar esta transicion con prueba de widget;
  cualquier artefacto exclusivamente visual debe reproducirse con captura o
  video antes de cambiar la animacion.
- Deep links, historial de navegacion y busqueda global no reemplazan la entrada
  del menu para una pantalla principal.
- Todo enlace entre modulos debe conservar una salida al contexto que lo abrio.
  La pantalla destino ofrece una accion visible de retorno (por ejemplo,
  `Volver al cliente`), que vuelve al perfil/lista origen; no depender solo de
  `pop()`/historial si el destino puede abrirse como deep link. Si se modifica
  un documento desde un perfil, guardar/cancelar tambien debe retornar a ese
  perfil y preservar el contexto funcional.
- Una lista de documentos debe abrir el detalle de cada registro mediante una
  accion visible; no dejar el registro accesible solo desde busquedas o perfiles.

## Registro por modulo

Cada cambio que agrega o promueve una pantalla principal actualiza esta tabla,
el menu del shell y una prueba de widget que confirme ruta y seleccion.

| Modulo | Entrada principal | Ruta indice | Accesos secundarios |
|---|---|---|---|
| Productos | Lista de productos | `/products` | Categorias, promociones, catalogo e importacion/exportacion tienen entradas propias. |
| Ventas | Agentes | `/sales/agents` | Entrada propia. |
| Ventas | Clientes | `/sales/customers` | Perfil y formularios desde lista/perfil. |
| Ventas | Cotizaciones | `/sales/quotes` | Formulario desde `Nueva cotizacion`. |
| Ventas | Pedidos | `/sales/orders` | Formulario desde `Nuevo pedido`. |
| Ventas | Facturas | `/sales/invoices` | Formulario desde `Nueva factura`. |
| Ventas | Devoluciones | `/sales/returns` | Crear y abrir detalle desde cada fila. |
| Ventas | Consignaciones | `/sales/consignments` | Crear y abrir detalle desde cada fila. |
| Inventario | Movimientos | `/inventory` | Bodegas y ubicaciones tienen entrada propia. |
| Global | Auditoria | `/audit` | Entrada propia. |
| Global | Configuracion | `/settings` | Secciones y formularios desde la pantalla. |

## Pruebas requeridas

- La prueba del shell debe recorrer cada entrada principal y afirmar la ruta
  exacta alcanzada.
- Si la pantalla se declara secundaria, la prueba de su pantalla padre debe
  afirmar que su CTA abre la ruta secundaria correspondiente.
- Al agregar o renombrar una ruta principal, actualizar esta tabla en el mismo
  cambio que la ruta, el menu y las pruebas.
