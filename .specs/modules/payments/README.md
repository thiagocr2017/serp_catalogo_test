# Payments Module Specs

Referencia viva para reglas de pagos, recibos, cuentas monetarias, anticipos,
creditos, reembolsos y reportes.

El SDD historico vive en `sdd-historical.md`. Este modulo requiere specs
antes de implementar pantallas completas.

`returns/1.sales-return-settlement.spec.md` define los limites de refund/credito
por devolucion. La implementacion requiere transaccion coordinada con Sales e
Inventory y pgTAP de idempotencia/concurrencia.
