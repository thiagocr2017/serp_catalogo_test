# Form Behavior Standard

## Proposito

Definir cuando un formulario debe ser una pantalla completa y cuando debe ser
un formulario rapido en modal.

## Formulario completo

Usar pantalla completa cuando la entidad o flujo necesita varias secciones,
validaciones cruzadas, datos opcionales importantes o una experiencia de trabajo
prolongada.

Ejemplos:

- crear/editar producto;
- crear/editar cliente;
- documentos de inventario;
- pedidos, facturas, guias o despachos.

Reglas:

- Debe ofrecer una salida persistente en el `leading` del `AppBar`: un boton
  icon-only con flecha y `tooltip` descriptivo (por ejemplo, `Volver`). Este es
  el patron compartido con perfiles/detalles; no usar un boton de texto en la
  zona de acciones como salida principal.
- El destino debe ser el contexto que abrio el formulario; cuando no se pueda
  conservar ese contexto, debe ser la lista/indice del modulo.
- Debe advertir si el usuario intenta salir con cambios sin guardar.
- La advertencia aplica al boton de cancelar, al retroceso de navegacion y al
  menu lateral de la app.
- Al guardar, cancelar descartando o salir aceptando la advertencia, el estado
  de cambios pendientes debe limpiarse.

## Formulario rapido

Usar modal cuando el usuario esta en otro flujo y solo necesita crear o editar
un dato auxiliar minimo para continuar.

Ejemplo aprendido:

- En el formulario completo de producto, si no existe la categoria buscada, se
  abre un modal para crear categoria con solo el nombre.

Reglas:

- Debe pedir solo lo estrictamente necesario.
- No debe replicar toda la pantalla completa de esa entidad.
- Si el usuario ya modifico algun campo, debe advertir antes de cerrar por
  cancelar, retroceso, Escape o cierre accidental del dialogo.
- Al guardar, debe cerrar el modal, refrescar el catalogo y seleccionar el dato
  nuevo cuando aplique.
- Si la entidad necesita configuracion avanzada, esa configuracion queda en su
  pantalla completa.
- El modal conserva controles propios de cerrar/cancelar y no incorpora el
  boton de retorno del `AppBar` reservado para formularios completos.

## Perfiles y pantallas de detalle

- Deben usar el mismo boton icon-only de flecha en el `leading` del `AppBar`,
  con tooltip que nombre el destino (por ejemplo, `Volver a clientes`).
- La accion navega al indice/contexto padre y sigue disponible durante carga y
  cuando el registro solicitado no existe.

## Consecuencia

Esta regla evita interrumpir un flujo principal por datos auxiliares, pero
tambien evita meter formularios grandes dentro de modales incomodos.
