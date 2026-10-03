# Sales Module Specs

Referencia viva para reglas de ventas, clientes, agentes, cotizaciones, pedidos,
facturas, devoluciones y consignaciones.

El SDD historico sigue en `SDD_Modulo_Ventas.md`.

## Specs nuevas

- `customer-management/0.open-questions.md`: decisiones pendientes antes del
  rediseño completo de Clientes.
- `customer-management/1.customer-data-model.spec.md`: modelo objetivo de datos
  del cliente.
- `customer-management/2.customer-catalogs.spec.md`: paises, provincias,
  ciudades, tipos de identificacion y categorias.
- `customer-management/3.customer-profile-queries.spec.md`: consultas necesarias
  para el perfil/display del cliente.
- `customer-management/4.customer-rankings.spec.md`: rankings comerciales por
  monto, frecuencia y LTV.
- `shipping/1.customer-shipping.spec.md`: borrador de envio, guias y rotulos.

## Regla para Clientes

No implementar el rediseño completo de Clientes sin resolver primero las
preguntas abiertas que afectan fiscalidad, credito, geografia, categorias,
envio y perfil comercial.
