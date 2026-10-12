# SDD - Módulo 4: Pagos y Recibos

## 1. Estado del documento y alcance vigente

Este documento describe el **diseño funcional** del módulo de Pagos y Recibos.
La afirmación anterior de que «el módulo todavía no está implementado» era
incorrecta: existe una implementación en `lib/modules/payments/`, cableada en
`main.dart`, con tablas, RPC y migraciones propias.

Por decisión del propietario (2026-10-03), este documento queda **alineado al
código**: lo que sigue es el alcance vigente y lo que queda fuera se declara
explícitamente en «Alcance futuro» (sección 15). El detalle verificado está en
`.specs/modules/payments/1.status.spec.md`.

### Alcance vigente

Implementado y operativo:

- pagos con uno o varios componentes de pago;
- estados `PENDING`, `CONFIRMED`, `CANCELLED` y `REFUNDED`;
- confirmación y anulación de pagos con motivo;
- catálogos de métodos de pago y cuentas monetarias, con alta y listado;
- gastos pagados desde una cuenta monetaria;
- traslados de dinero entre cuentas, como par atómico salida/entrada;
- reembolsos parciales o totales de un pago;
- moneda original, tipo de cambio y equivalente en USD por componente (contrato
  persistente vigente; su alineacion con la moneda configurable queda pendiente).

Las escrituras se ejecutan mediante las RPC `SECURITY DEFINER` del módulo
(`create_payment`, `confirm_payment`, `cancel_payment`, `create_payment_method`,
`create_money_account`, `create_expense`, `create_refund`,
`transfer_between_accounts`), que son el camino correcto: las tablas solo
conceden `SELECT` a `anon` y `authenticated`. Es el patrón que exige
`.specs/architecture/module-security-contract.md` §6.

### Fuera de alcance por ahora

Ver sección 15. En particular quedan pendientes: anticipos y créditos a favor
del cliente, notas de crédito, depósitos sin identificar, aplicación de pagos a
facturas, series de recibo por usuario, comprobantes impresos, permisos por
operación, reportes mensuales y operación sin conexión.

## 2. Propósito y límites

El módulo administrará:

- cobros de clientes;
- recibos emitidos al confirmar dinero realmente recibido;
- aplicaciones de uno o varios pagos a una o varias facturas;
- pagos parciales y combinación de métodos o monedas;
- anticipos y créditos a favor de clientes;
- reembolsos completos o parciales;
- cuentas monetarias de empresa: caja, bancos y caja fuerte;
- gastos pagados directamente desde una cuenta;
- traslados de dinero entre cuentas;
- reportes mensuales de entradas, salidas y comisiones;
- operación offline idempotente.

La primera versión no administrará cuentas por pagar a proveedores ni
conciliación bancaria. Un gasto confirmado reduce una cuenta monetaria, pero no
crea una deuda futura con un proveedor.

## 3. Propiedad de responsabilidades

### Ventas

Ventas es propietario de clientes, facturas, notas de crédito, saldo original y
estado comercial del documento. Expone a Pagos el saldo pendiente y recibe el
resultado de las aplicaciones confirmadas.

### Pagos

Pagos es propietario del dinero recibido, métodos, componentes monetarios,
aplicaciones, créditos del cliente, recibos, reembolsos, gastos y movimientos
entre cuentas.

Pagos no modifica el total original de una factura. Ventas no inserta
directamente movimientos monetarios.

## 4. Conceptos principales

### 4.1 Pago y recibo

Un pago puede estar `PENDING`, `CONFIRMED`, `CANCELLED` o `REFUNDED`.

- `PENDING`: todavía no afecta facturas, créditos ni cuentas monetarias.
- `CONFIRMED`: el dinero se considera recibido y se aplican sus efectos.
- `CANCELLED`: revierte mediante movimientos compensatorios todos sus efectos.
- `REFUNDED`: conserva el pago y registra uno o varios reembolsos relacionados.

El recibo no es un registro independiente del dinero: es el comprobante
inmutable generado cuando el pago se confirma. Un pago pendiente no tiene
recibo definitivo.

### 4.2 Componentes de pago

Un pago puede combinar varios componentes. Cada componente conserva:

- método de pago;
- cuenta monetaria de destino;
- moneda original;
- importe original;
- tipo de cambio utilizado;
- equivalente en USD, segun el contrato persistente vigente;
- referencia bancaria, autorización, cheque o depósito, cuando exista.

La regla de producto define como moneda de referencia la configurada en
Configuracion. El esquema y la API actuales aun nombran y guardan el equivalente
como USD; alinearlos con cualquier moneda de referencia es una migracion
pendiente y no debe confundirse con una conversion disponible en Ventas.

### 4.3 Aplicaciones

Un pago puede aplicarse a varias facturas y una factura puede recibir varios
pagos. Cada aplicación conserva el importe aplicado y no puede superar el saldo
vigente de la factura.

No se puede aplicar dinero a una factura anulada. Si se anula una factura
pagada, el dinero aplicado se convierte en crédito del cliente; no desaparece ni
se reasigna automáticamente.

> La frontera exacta con Ventas, sus DTO, sus comandos, la atomicidad, la
> idempotencia y las reglas de borde están definidas en
> [`../../04-sales-payments-contract.md`](../../04-sales-payments-contract.md).
> Este documento no las repite. Toda esa sección queda **aplazada** conforme a
> la sección 15.

### 4.4 Anticipos y créditos

Se permite recibir dinero sin factura únicamente como anticipo identificado de
un cliente. El anticipo confirmado incrementa su crédito disponible.

Al crear o cobrar una factura, Ventas debe mostrar:

- saldo pendiente del cliente;
- crédito disponible;
- notas de crédito pendientes de aplicación.

El usuario decide cuánto crédito aplicar. Si el crédito supera el saldo de la
factura, solo se utiliza el importe necesario y el remanente continúa
disponible.

Ejemplo:

```text
Anticipo disponible: USD 500
Factura pendiente: USD 300
Crédito aplicado: USD 300
Crédito restante: USD 200
```

Los créditos no pueden transferirse entre clientes.

### 4.5 Depósitos sin identificar

Un depósito sin cliente conocido se registra en una cuenta transitoria de
depósitos pendientes de identificar. No genera recibo de cliente. Al
identificarlo se crea el pago, se mueve el importe a su destino definitivo y se
emite el recibo.

Un depósito bancario puede agrupar varios recibos, pero la relación debe quedar
registrada sin fusionar las deudas o créditos de los clientes.

## 5. Métodos y cuentas monetarias

Los métodos de pago serán dinámicos y administrables desde Configuración. Cada
método define los datos que puede solicitar, pero referencias y autorizaciones
serán opcionales inicialmente.

Las cuentas monetarias pertenecen a una empresa y moneda. Tipos iniciales:

- caja;
- cuenta bancaria;
- caja fuerte;
- depósitos pendientes de identificar;
- otras cuentas configurables.

La caja no tendrá apertura, turno ni arqueo en la primera versión. Funcionará
como una cuenta que recibe efectivo y permite gastos, salarios, comisiones,
reembolsos y traslados hacia bancos o caja fuerte.

Solo los agentes con permiso explícito pueden cobrar. Puede asignarse una caja a
un agente, pero una caja no implica automáticamente autorización para recibir
dinero.

## 6. Monedas y tipo de cambio

La regla funcional define como moneda de referencia la configurada en
Configuración. Pagos es el unico modulo autorizado a capturar tipo de cambio,
exclusivamente al recibir dinero en otra moneda, para registrar el importe
recibido y su equivalente en la moneda de referencia. El modelo persistente
actual aun utiliza `usd_equivalent`; migrarlo para soportar la moneda
configurable es trabajo pendiente. Otras pantallas no deben ofrecer tipo de
cambio.

Cada componente en moneda diferente debe conservar:

```text
moneda original recibida
importe original recibido
tipo de cambio acordado por la empresa
equivalente en la moneda de referencia configurada (actualmente persistido como
`usd_equivalent`)
fecha y hora del cálculo
```

El tipo de cambio histórico nunca se recalcula. Las diferencias permanecen como
saldo por cobrar o crédito a favor, según el resultado real de la aplicación.

## 7. Reembolsos, anulaciones y notas de crédito

- Un pago confirmado no se edita ni elimina.
- Una corrección se realiza anulando y creando un pago nuevo.
- Transferencias rechazadas, cheques devueltos y contracargos anulan el pago y
  restauran la deuda correspondiente.
- Toda anulación exige motivo y conserva recibo, número e historial con marca
  visible de anulado.
- Una nota de crédito comercial devuelve los productos mediante Ventas e
  Inventario y crea crédito monetario para el cliente.
- Un reembolso puede ser total o parcial y no tiene que utilizar el método de
  pago original.
- Los reembolsos requieren permiso de gerente y nunca pueden superar el crédito
  disponible.
- Un reembolso bancario solo se confirma cuando la empresa realmente lo
  procesa; no se anticipa contablemente como completado.

## 8. Numeración y comprobantes

Cada usuario autorizado puede tener su propia serie, pero el número completo
debe ser globalmente único y asignado por PostgreSQL al confirmar.

Ejemplos:

```text
TL-RC-000125
AM-RC-000073
```

No se registrarán recibos manuales externos. El recibo podrá imprimirse,
exportarse a PDF y compartirse. Debe incluir:

- empresa y logo;
- número, fecha y estado;
- firma digital visual;
- usuario o agente;
- cliente;
- facturas y montos aplicados;
- métodos, monedas y equivalentes;
- crédito generado o utilizado;
- saldo restante.

No se adjuntarán fotografías ni PDF de comprobantes bancarios inicialmente.
Las plantillas A4 y ticket térmico de 80 mm deben cumplir
`.specs/architecture/document-standards.md`.

## 9. Gastos y movimientos entre cuentas

Un gasto confirmado registra concepto, beneficiario opcional, categoría,
importe, moneda, cuenta de origen, usuario y fecha. Salarios, comisiones y gastos
menores utilizan este mecanismo mientras no exista un módulo contable más
amplio.

Un traslado monetario genera dos movimientos atómicos:

```text
salida de la cuenta origen
entrada en la cuenta destino
```

Las comisiones bancarias o de tarjeta se registran como gastos separados; no
reducen el pago reconocido al cliente. Las comisiones de agentes se calcularán
sobre pagos confirmados, no solo sobre facturas emitidas.

## 10. Reportes mensuales

El módulo debe producir un cierre informativo por intervalo, sin cierre formal
de turno:

- cobros confirmados por método y moneda;
- efectivo recibido;
- depósitos y transferencias;
- gastos y reembolsos;
- movimientos entre cuentas;
- saldo calculado por cuenta;
- cobros por agente;
- base y cálculo de comisiones;
- créditos generados, utilizados y pendientes.

## 11. Seguridad y auditoría

Existirán permisos independientes para:

- crear pagos pendientes;
- confirmar pagos;
- anular pagos;
- registrar gastos;
- trasladar dinero;
- confirmar reembolsos;
- consultar cuentas y reportes.

El gerente autoriza reembolsos. Las reglas monetarias adicionales dependerán
del futuro módulo de usuarios y permisos.

El sistema alertará referencias bancarias repetidas. Continuar ante una posible
duplicación requerirá permiso especial y motivo.

Toda creación, confirmación, aplicación, anulación, reembolso y traslado registra
usuario, dispositivo, fecha, comando idempotente y valores relevantes. Los
libros monetarios y de crédito son inmutables; las correcciones se realizan con
movimientos compensatorios.

## 12. Operación sin conexión y concurrencia

Cada comando recibe un UUID antes de guardarse en una cola local cifrada. Los
reintentos conservan el UUID y PostgreSQL devuelve el resultado anterior en vez
de duplicarlo.

Offline se entrega únicamente un comprobante provisional con código local y
marca pendiente de sincronización. El servidor asigna el recibo definitivo al
sincronizar.

Al aplicar pagos, PostgreSQL bloquea las facturas afectadas, recalcula sus saldos
y confirma pago, componentes, aplicaciones, crédito y movimientos de cuentas en
una transacción. Si otro equipo pagó primero, el segundo utiliza el saldo nuevo;
el excedente confirmado se convierte en crédito del cliente.

Los conflictos que no puedan resolverse automáticamente permanecen visibles y
no pierden la operación local original.

## 13. Modelo persistente objetivo

El diseño detallado se validará antes de crear migraciones. Entidades previstas:

- `payment_methods`;
- `money_accounts`;
- `payments`;
- `payment_components`;
- `payment_applications`;
- `receipts` o proyección inmutable del pago confirmado;
- `customer_credit_entries`;
- `refunds`;
- `expenses`;
- `money_account_transactions`;
- `unidentified_deposits`;
- `user_receipt_series`;
- `offline_payment_commands` o cola local equivalente.

Los saldos de facturas, clientes y cuentas serán proyecciones derivadas de
libros inmutables, no valores modificados libremente por la interfaz.

## 14. Integraciones

- **Ventas:** facturas, clientes, notas de crédito y saldos comerciales.
- **Inventario:** devoluciones físicas relacionadas con notas de crédito; Pagos
  no modifica existencias.
- **Configuración:** empresa, logo, monedas, redondeo y métodos de pago.
- **Usuarios:** permisos, series, gerente y agentes autorizados.
- **PDF/compartir:** recibos y reportes mensuales.

Las integraciones se realizarán mediante API pública de cada módulo. Confirmar
una operación que afecte varios módulos exigirá una función transaccional de
PostgreSQL.

## 15. Alcance futuro

Por decisión del propietario (2026-10-03) el documento queda alineado al
código. Todo lo siguiente queda **fuera del alcance vigente** y no debe
prometerse como disponible:

### Del diseño original, aplazado

- aplicaciones de pago a una o varias facturas, y el límite de saldo por
  factura (sección 4.3);
- anticipos y créditos a favor del cliente, y su aplicación parcial
  (sección 4.4);
- depósitos sin identificar y su posterior identificación (sección 4.5);
- notas de crédito comerciales (sección 7);
- series de recibo por usuario y numeración definitiva asignada por
  PostgreSQL al confirmar (sección 8);
- recibo impreso o exportable con A4, ticket de 80 mm y ESC/POS (sección 8);
- permisos independientes por operación y autorización de reembolsos por
  gerente (sección 11);
- alerta de referencias bancarias repetidas (sección 11);
- reportes mensuales de entradas, salidas y comisiones (sección 10);
- operación sin conexión con cola local cifrada y comprobante provisional
  (sección 12);
- límite de crédito disponible y saldo por cobrar consultables desde Ventas.

### De la primera versión, excluido

- cuentas por pagar y vencimientos de compras a proveedores;
- conciliación o importación de estados bancarios;
- arqueos y turnos de caja;
- adjuntos de comprobantes;
- contabilidad general y asientos contables completos;
- traslado de créditos entre clientes.

Cuando se retome cualquiera de estos puntos, se crea su spec concreta en
`.specs/modules/payments/` antes de implementarlo.

## 16. Deuda y decisiones para la implementación

- Definir el contrato público definitivo entre Ventas y Pagos antes de crear
  facturas persistentes.
- Diseñar la identidad y permisos reales; la identidad del equipo es insuficiente
  para aprobar reembolsos o mantener series personales.
- Elegir almacenamiento local cifrado para la cola offline de escritorio y la
  futura aplicación Android.
- Definir categorías de gastos y reglas configurables de comisión.
- Decidir si depósitos agrupados requieren una entidad de lote bancario aunque
  no exista conciliación.
- Automatizar pruebas de concurrencia, idempotencia, redondeo, múltiples monedas,
  anulaciones y reembolsos parciales.
