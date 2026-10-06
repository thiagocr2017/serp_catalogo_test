# Retorno al Contexto de Origen

## Regla transversal

Todo enlace que sale de una pantalla o modulo hacia otro contexto funcional
debe ofrecer una salida visible que retorne al origen. No asumir que el usuario
puede reconstruirlo desde el menu, navegador o historial.

## Contrato de retorno

- Al abrir un detalle desde una lista, el destino muestra `Volver a <lista>`.
- Al abrir un documento desde un perfil (por ejemplo cotizacion desde perfil de
  cliente), el destino muestra `Volver al cliente` y vuelve al mismo perfil.
- Al abrir mediante deep link sin origen, usar un destino estable del modulo,
  no un `pop()` que pueda cerrar la aplicacion.
- Acciones de estado/confirmacion mantienen el mismo contexto de retorno.
- Formularios con cambios sin guardar confirman salida antes de navegar.
- El destino valida rutas de retorno contra una lista permitida; no navega a
  rutas externas/arbitrarias provenientes de parametros.
- El indice principal de cada modulo permanece disponible en el menu lateral,
  aunque el detalle se haya abierto desde otro modulo.

## Pruebas obligatorias

- Origen lista -> detalle -> retorno llega al indice exacto.
- Origen perfil -> documento -> retorno llega al ID exacto del perfil.
- Deep link sin contexto vuelve al indice del modulo.
- Una mutacion intermedia no pierde el retorno.
- Navegacion con cambios sin guardar respeta `UnsavedChangesGuard`.
- Ruta de retorno desconocida/invalida cae al indice seguro configurado.
