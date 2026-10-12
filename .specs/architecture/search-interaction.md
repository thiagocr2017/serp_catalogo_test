# Interaccion de busqueda

## Regla transversal

- Las busquedas de listas, catalogos y selectores de registros se activan al
  alcanzar tres caracteres Unicode (ignorando espacios externos).
- Con cero, uno o dos caracteres, el termino efectivo queda vacio y se muestran
  los resultados sin filtrar; borrar hasta ese umbral restaura inmediatamente
  esos resultados.
- La busqueda local filtra en el mismo cambio de texto. Las consultas remotas
  esperan 250 ms desde la ultima pulsacion por defecto; Enter puede ejecutarlas
  antes. La lista de Productos usa 150 ms como optimizacion especifica, con
  resultados previos visibles durante la consulta.
- Un control explicito para limpiar, cuando exista, vacia el campo y restaura
  todos los resultados/filtros asociados.
- Los filtros independientes (estado, categoria, fecha, tipo o precio) se
  conservan cuando cambia o se limpia el texto de busqueda.
- Campos estructurados de formularios (por ejemplo, nombre, direccion o codigo
  de color) no son busquedas y quedan fuera de esta regla. Los autocomplete de
  clientes, productos y documentos si son selectores de busqueda.

## Implementacion

- Usar `lib/shared/utilities/search_query.dart` y
  `effectiveSearchQuery` para aplicar el umbral de forma consistente.
- Evitar consultas remotas por cada tecla; cancelar cualquier debounce al
  borrar, al enviar la busqueda o al disponer la pantalla.
- Probar el umbral, el filtrado desde el tercer caracter y la restauracion al
  reducir/borrar el texto.
