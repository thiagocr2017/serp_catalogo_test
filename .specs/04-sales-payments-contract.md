# 04 - Contrato publico Ventas <-> Pagos

## Proposito

Definir la frontera entre `sales` y `payments` **antes** de crear facturas
persistentes con aplicaciones de pago, para que el estado `PAID`, las notas de
credito y el saldo del cliente no se disenen dos veces.

Decision del propietario (2026-10-03): definirlo ahora como spec, aun cuando
su implementacion este aplazada por R2 (`.specs/modules/payments/sdd-historical.md` §15).

Este contrato complementa `.specs/architecture/module-security-contract.md` y no lo debilita. Si
hay conflicto, gana ese documento.

## Estado de partida verificado

Comprobado el 2026-10-03 sobre la base local:

| Hecho | Consecuencia para el contrato |
|---|---|
| `sales_invoices` **no** tiene columna de saldo ni de importe pagado | El saldo vigente es una proyeccion derivada, no un campo editable |
| `customers.current_balance` y `customers.credit_limit` solo los escriben `create_customer` y `update_customer` | Ningun cobro actualiza hoy el saldo del cliente |
| **No hay triggers** sobre `payments`, `payment_applications`, `sales_invoices`, `customers` ni `customer_credit_entries` | Ningun saldo se mantiene solo; hay que declarar quien lo hace |
| `payment_applications.invoice_id` es un `uuid` **sin clave foranea** | La pertenencia de la aplicacion a una factura no esta impuesta por el esquema |
| `payments.customer_id` y `customer_credit_entries.customer_id` son `uuid` **sin clave foranea** | Igual |
| `payment_applications` tiene solo `payment_id`, `invoice_id`, `amount_applied`, `created_at` | Falta moneda, tipo de cambio e historico |
| `create_payment` recibe `p_command_id` | Solo el pago es idempotente hoy |

## Propiedad

### Ventas conserva

- `customers`, `customer_contacts`, `sales_invoices`, `sales_invoice_lines` y
  `sales_invoice_commands`;
- el total original de una factura y su estado comercial;
- las notas de credito comerciales (cuando existan), junto con su impacto
  fisico en Inventario;
- `customers.credit_limit` como politica comercial;
- `customers.current_balance` como **proyeccion** que refleja deuda y credito.

### Pagos conserva

- `payments`, `payment_components`, `payment_applications`, `refunds`,
  `customer_credit_entries`, `money_accounts`, `money_account_transactions`,
  `expenses` y `unidentified_deposits`;
- el dinero realmente recibido, sus metodos y sus cuentas destino;
- el historico de aplicaciones, reembolsos y creditos a favor.

### Reglas de no interferencia

- Pagos **no** modifica el total original de una factura ni su estado
  comercial.
- Ventas **no** inserta movimientos monetarios, recibos ni reembolsos.
- Ninguno de los dos escribe tablas del otro directamente: cada uno lo hace
  mediante su propia RPC.

## Comunicacion permitida

### Ventas expone a Pagos

Consultas de lectura, con DTO minimo y sin capacidad de escritura:

```text
InvoiceBalanceDto {
  invoiceId        // opaco para Pagos
  customerId       // opaco
  customerName     // snapshot
  currencyCode
  totalAmount      // total original, inmutable
  appliedAmount    // suma de aplicaciones confirmadas
  outstandingAmount// totalAmount - appliedAmount
  status           // DRAFT | CONFIRMED | CANCELLED | PAID
  isVoid
}

SalesApiForPayments {
  getInvoiceBalance(invoiceId) -> InvoiceBalanceDto?        // null si no existe
  listOpenInvoices(customerId) -> List<InvoiceBalanceDto>   // outstandingAmount > 0 y no anuladas
}
```

Comando, unico punto de escritura de Ventas por parte de un cobro:

```text
RecordPaymentApplicationCommand {
  commandId      // UUID idempotente, obligatorio
  paymentId      // opaco para Ventas
  invoiceId
  amountApplied
  currencyCode
  exchangeRate   // tipo de cambio historico, nunca recalculado
  referenceCurrencyEquivalent
}

SalesApiForPayments {
  recordPaymentApplication(RecordPaymentApplicationCommand)
      -> RecordPaymentApplicationResult { applied, newOutstanding, invoiceStatus }
}
```

Ventas valida y escribe. El consumidor nunca repite esa escritura por su cuenta
(`.specs/architecture/module-security-contract.md` §4, comando sincrono).

### Pagos expone a Ventas

```text
CustomerCreditSummaryDto {
  customerId
  availableCredit        // anticipos y notas de credito sin aplicar
  outstandingBalance     // deuda vigente
  pendingCreditNotes
  recentPayments         // minimo: fecha, importe, moneda, estado
}

PaymentApiForSales {
  getCustomerCreditSummary(customerId) -> CustomerCreditSummaryDto
  getInvoicePayments(invoiceId)        -> List<PaymentSummaryDto>
}
```

Ventas **no** recibe comandos de Pagos para escribir dinero: no los necesita.

## Atomicidad

Confirmar un cobro aplicado a facturas escribe, en una **unica transaccion de
PostgreSQL**, todo o nada:

1. estado del pago y sus componentes;
2. filas de `payment_applications`;
3. saldo vigente de cada factura afectada (proyeccion en Ventas);
4. `customers.current_balance` (proyeccion en Ventas);
5. entrada en `customer_credit_entries` cuando sobre dinero;
6. auditoria consolidada de ambos lados.

Si algo falla, no queda ni el cobro ni la aplicacion. No se mantiene la
transaccion abierta esperando usuario, impresora, red ni servicio externo
(`.specs/architecture/module-security-contract.md` §5).

La forma prevista es una funcion orquestadora propietaria de **Pagos** que,
dentro de la misma transaccion, invoca el comando publico de Ventas. Asi cada
modulo sigue escribiendo sus propias tablas y la atomicidad se conserva.

Alternativa descartada: que Ventas orqueste.
- Razon a favor: Ventas es quien conoce el saldo.
- Consecuencia: un cobro no se crea al facturar, asi que Ventas tendria que
  invocar la creacion de dinero en Pagos, que es al reves de la propiedad
  declarada. Se descarta.

## Idempotencia

- Todo comando que cruza la frontera recibe `commandId` obligatorio.
- Un reintento con la misma `commandId` devuelve el resultado previo y no
  repite efectos de negocio ni duplica aplicaciones
  (`.specs/architecture/module-security-contract.md` §5 y §9).
- Hoy solo `create_payment` recibe `p_command_id`. Las demas RPC del alcance
  vigente necesitaran clave si van a soportar reintentos o cola offline.

## Reglas de borde

| Situacion | Comportamiento |
|---|---|
| Aplicar a una factura anulada | Rechazado por Ventas, con error tipado. El dinero no se pierde: queda como credito del cliente |
| Anular una factura ya pagada | El dinero aplicado se convierte en credito del cliente. No se reasigna ni se devuelve automaticamente |
| La aplicacion supera el saldo vigente | Rechazado. El consumidor no puede forzarlo |
| Dos equipos aplican a la vez sobre la misma factura | PostgreSQL bloquea las filas, recalcula el saldo y usa el saldo nuevo. El excedente confirmado se convierte en credito |
| Pago en moneda distinta | Solo Pagos conserva moneda original, importe original, tipo de cambio historico y equivalente en la moneda de referencia configurada. El tipo de cambio nunca se recalcula |
| Reintento con la misma `commandId` | Devuelve el resultado previo. No duplica aplicaciones |
| Error intermedio | Reversion completa: ni cobro ni aplicacion |

## Estado de implementacion

Este contrato esta **definido y no implementado**. Su alcance cae dentro de lo
aplazado en `.specs/modules/payments/sdd-historical.md` §15 (aplicaciones de pago, creditos a favor,
notas de credito) y de la Fase 7 de `.specs/refactors/02-tech-debt-plan.md`.

Lo que si existe hoy y no contradice este contrato:

- `create_payment` con `p_command_id` idempotente y componentes;
- `confirm_payment`, `cancel_payment`, `create_refund`;
- `payment_applications` y `customer_credit_entries` como tablas vacias;
- `sales_invoices.status` con `DRAFT`, `CONFIRMED`, `CANCELLED`, `PAID`.

## Devoluciones de venta (extension requerida)

La devolucion tiene una frontera adicional, especificada en
`.specs/modules/sales/returns/1.return-business.spec.md`,
`.specs/modules/sales/returns/2.database-contract.spec.md` y
`.specs/modules/payments/returns/1.sales-return-settlement.spec.md`.

- Sales conserva la devolucion comercial, snapshot de factura y reduccion de
  deuda. Inventory conserva destinos/movimientos, y Payments conserva refunds y
  creditos.
- Decision de esta implementacion: Sales es propietario del agregado devolucion
  y `sales_confirm_return` orquesta en una transaccion las RPC publicas de
  Inventory y Payments. Cada modulo escribe unicamente sus tablas; la frontera
  se verifica con el test de arquitectura y pgTAP de atomicidad.
- Se reduce primero la deuda impaga. Solo el excedente se devuelve como dinero
  o credito, elegido de forma excluyente una vez por devolucion. No se crea
  valor financiero por deuda no pagada.
- Payments valida bajo bloqueo la capacidad financiera por factura (pagos
  confirmados menos refunds no rechazados) y registra un refund/credito ligado
  una sola vez a la devolucion. Los refunds conservan estado `PENDING` para no
  omitir el flujo historico de autorizacion. El credito se limita igualmente a
  dinero recibido y solo al excedente luego de reducir la deuda.
- La misma transaccion incluye movimientos de Inventory; un fallo financiero o
  fisico revierte todos los efectos. Cuarentena y exclusion de stock vendible
  pertenecen a Inventory, no a una escritura de Sales.
- El alta transaccional esta implementada por
  `20261007100000_atomic_sales_returns.sql`. No se implementan aun anulacion
  compensatoria ni pruebas multi-sesion; por ello una devolucion confirmada no
  se puede liberar/reutilizar desde la UI.

## Tareas

- [ ] Anadir `currencyCode`, `exchangeRate`, `referenceCurrencyEquivalent` y `commandId` a
      `payment_applications`.
- [ ] Decidir si `payment_applications.invoice_id`, `payments.customer_id` y
      `customer_credit_entries.customer_id` llevan clave foranea. Restriccion:
      una FK cruzada acopla esquemas y dificulta la propiedad por modulo; la
      alternativa es validar la pertenencia dentro de las RPC. Se recomienda
      validar en RPC y dejar la referencia logica, salvo que se acepte el
      acoplamiento por integridad referencial.
- [ ] Especificar la funcion orquestadora transaccional y su propiedad.
- [ ] Definir como se deriva y se persiste `customers.current_balance`.
- [ ] Especificar la conversion de saldo pagado en credito al anular facturas.
- [ ] Pruebas minimas: aplicacion valida, rechazo por factura anulada, rechazo
      por exceso de saldo, idempotencia por `commandId`, doble envio
      concurrente y reversion ante fallo intermedio.
- [x] Devoluciones: elegibilidad, refund/credito idempotentes, capacidad bajo
      bloqueo, referencia unica y pgTAP base en
      `modules/sales/returns/2.database-contract.spec.md`.
- [ ] Devoluciones: concurrencia multi-sesion y anulacion compensatoria antes
      de permitir cancelar o reutilizar lineas devueltas.

## Criterio de listo

1. Cada operacion que cruza la frontera tiene DTO, comando y error tipado
   declarados aqui.
2. La prueba de frontera sigue pasando: ningun modulo importa capas internas
   del otro.
3. Las pruebas de atomicidad, idempotencia y concurrencia existen antes de
   habilitar la escritura cruzada.
4. `.specs/modules/payments/sdd-historical.md` §4.3 y `.specs/modules/sales/sdd-historical.md` §6 apuntan a este
   contrato en vez de repetir sus reglas.
