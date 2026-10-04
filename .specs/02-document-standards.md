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

Este archivo **no** vuelve a enunciar las reglas: solo las resume. La unica
fuente normativa es
[`architecture/document-standards.md`](architecture/document-standards.md),
que contiene contenido, nombres de archivo, almacenamiento, plantillas A4 y
termica, transporte ESC/POS, validacion obligatoria y la **definicion de
formulario listo** de su seccion 12.

Regla de resolucion: ante cualquier duda o conflicto se aplica
`architecture/document-standards.md`. **No** se duplica una regla aqui; se
enlaza. Enunciar la misma regla en dos sitios es lo que produjo la deriva
documental corregida en `refactors/01-document-consistency.md`.
