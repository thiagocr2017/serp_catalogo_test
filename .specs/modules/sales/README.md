# Sales Module Specs

Referencia viva para reglas de ventas, clientes, agentes, cotizaciones, pedidos,
facturas, devoluciones y consignaciones.

El SDD historico sigue en `SDD_Modulo_Ventas.md`.

## Specs nuevas

- `customer-management/0.open-questions.md`: **registro canonico de las 44
  decisiones de Clientes**. Las 23 preguntas abiertas se cerraron el
  2026-10-03.
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

**Las preguntas abiertas quedaron resueltas el 2026-10-03.** El registro
canonico de las 44 decisiones esta en
`customer-management/0.open-questions.md` (seccion B, decisiones 20 a 44).

El rediseño de Clientes ya puede implementarse. Antes de hacerlo hay que leer
ese registro: fija datos fiscales, identificacion, geografia, envio, rankings,
alertas del perfil y la estructura de la guia de carga.

Quedan sueltas solo dos preguntas menores del PIN de aprobacion (longitud y
modo de entrega), en
`../authorization/1.one-time-pin-approval.spec.md`.
