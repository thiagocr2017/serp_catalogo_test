# Patrones de listas

## Proposito

Definir el papel de cada lista y los comportamientos esperados para que las
pantallas nuevas y existentes sean localizables, comprensibles y consistentes.

## Tipos

1. **Lista indice o principal**: vista cuyo objetivo principal es encontrar y
   abrir/operar registros (p. ej. productos, clientes, cotizaciones,
   devoluciones). Tiene ruta propia y entrada desde la navegacion global.
2. **Lista contextual o informativa**: muestra historial, resumen o relaciones
   dentro de otra pantalla (p. ej. documentos y productos frecuentes del
   perfil del cliente). Conserva el contexto padre y enlaza al registro cuando
   exista una pantalla de detalle.
3. **Lista de composicion**: conjunto editable que el usuario construye como
   parte del resultado de una operacion (p. ej. lineas de una cotizacion,
   factura o devolucion). Su estado y validacion pertenecen al formulario que
   la contiene.

Un selector/buscador de registros es un control de entrada, no un cuarto tipo
de lista. Puede reutilizar patrones de busqueda de la lista indice sin heredar
su navegacion ni sus acciones.

## Contrato de lista indice

- La pantalla tiene una ruta estable y una entrada visible en el menu lateral
  si representa una seccion principal.
- Cada resultado permite identificar el registro y abrir su detalle o contexto
  de trabajo mediante una accion visible; un menu overflow no sustituye esa
  accion.
- La busqueda y los filtros disponibles son explicitos, combinables y
  reiniciables. El estado vacio diferencia "sin registros" de "sin resultados
  para estos criterios".
- Las acciones por fila se limitan a operaciones validas para el estado y
  permisos actuales. Acciones secundarias no deben impedir abrir el registro ni
  desbordar el ancho disponible.
- Si hay exportacion, se aclara si exporta todo el conjunto o el resultado
  filtrado. La exportacion del resultado filtrado debe respetar exactamente la
  busqueda, filtros, orden y alcance visibles; debe indicarse el formato y
  comunicarse errores sin perder los criterios.
- El acceso a otro modulo conserva un retorno claro al origen cuando el flujo
  no sea una navegacion global deliberada. Ver
  `navigation-return-context.md`.
- Las listas grandes deben cargar por paginas/lotes; no se debe exportar solo
  la pagina visible cuando la etiqueta promete exportar todo lo filtrado.

## Contrato de lista contextual

- El encabezado explica que relacion o periodo resume.
- Se muestran conteo/estado vacio y datos suficientes para decidir si abrir el
  registro.
- Cada fila navegable tiene affordance visible y mantiene un retorno al padre.
- Un resumen de alertas que deriva de registros debe explicar su conteo y
  ofrecer un acceso directo con el filtro correspondiente, no ser un callejon
  sin salida.

## Contrato de lista de composicion

- Cada linea permite identificar producto, presentacion/unidad, cantidad,
  precio, descuento y subtotal aplicables a ese documento.
- Los controles de editar/eliminar son visibles y caben en los anchos
  soportados; acciones no se esconden exclusivamente tras overflow.
- Subtotales y total se recalculan al cambiar valores y sus reglas se describen
  en la spec de negocio/formulario.
- Los errores de validacion quedan junto a la linea y no ejecutan persistencia.
- Datos operativos internos (p. ej. stock) no se filtran a salidas para
  clientes, salvo que el contrato documental lo permita expresamente.

## Verificacion

Cada pantalla lista debe tener pruebas para busqueda/filtros, vacio, apertura
del elemento y acciones disponibles. Si exporta, probar exportacion completa y
filtrada con mas de una pagina de resultados. Cada formulario con lista de
composicion debe probar altas, ediciones, eliminaciones, calculos y validacion.
