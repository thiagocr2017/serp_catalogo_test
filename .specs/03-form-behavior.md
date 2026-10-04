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

## Consecuencia

Esta regla evita interrumpir un flujo principal por datos auxiliares, pero
tambien evita meter formularios grandes dentro de modales incomodos.
