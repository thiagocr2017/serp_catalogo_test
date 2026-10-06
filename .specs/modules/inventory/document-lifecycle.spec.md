# Ciclo de vida de documentos de inventario

## Traslado diferido

- Crear con `p_draft = true` persiste encabezado y lineas con estado `BORRADOR`
  pero no mueve existencias.
- Despachar es la confirmacion de salida: crea `TRANSFER_OUT` por linea y
  cambia a `DESPACHADA` de forma atomica.
- Reintentar la misma transicion cuando ya esta `DESPACHADA` no agrega nuevos
  movimientos.
- `mark_transfer_in_transit` bloquea la fila, valida tipo y estado, y cambia
  `DESPACHADA` a `EN_TRANSITO`; un reintento en destino es un no-op exitoso.
- `receive_transfer` cambia `EN_TRANSITO` a `RECIBIDA` y registra `TRANSFER_IN`
  por linea dentro de la misma transaccion; bloquea y valida la fila, y el
  reintento en `RECIBIDA` no duplica movimientos.
- El cliente no debe poder realizar una transicion con efecto de stock usando
  una RPC que solo cambie el estado.

## Verificacion requerida

`supabase/tests/database/inventory_document_integrity_test.sql` comprueba
borrador -> despacho -> tránsito -> recepción, saldos de origen/destino y
reintentos. La pantalla tiene contrato propio en
`.specs/screens/inventory-documents/`.
