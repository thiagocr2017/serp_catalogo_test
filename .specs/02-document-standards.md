# 02 - Estandar de Documentos

## Salidas obligatorias

Todo documento confirmado debe poder producir:

- PDF A4 formal.
- Ticket termico de 80 mm.
- ESC/POS directo para impresora termica, sin PDF intermedio.

## Perfil inicial

- Impresora inicial: Rongta RPP300.
- Papel: 80 mm.
- Ancho imprimible: 72 mm.
- Resolucion: 203 dpi.

## Criterio de listo

Un documento no se marca como completo si solo existe una salida. La spec de la
pantalla o modulo debe indicar que campos aparecen en A4, ticket y ESC/POS, y
las pruebas deben verificar al menos la generacion de las salidas disponibles en
el alcance implementado.

## Referencia

Este archivo resume `DOCUMENT_STANDARDS.md`. Las reglas detalladas de contenido,
nombres, almacenamiento, validacion y definicion de formulario listo permanecen
en ese documento hasta completar la migracion.
