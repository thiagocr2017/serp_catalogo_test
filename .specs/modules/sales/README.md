# Sales Module Specs

Referencia viva para reglas de ventas, clientes, agentes, cotizaciones, pedidos,
facturas, devoluciones y consignaciones.

El SDD historico vive en `sdd-historical.md`.

## Specs nuevas

- `../../screens/sales-commercial-operations/`: flujos de UI para cotizaciones,
  pedidos, facturas, devoluciones y consignaciones usando los comandos
  comerciales ya expuestos.
- `../../screens/sales-quote-form/`: alta rapida, descuentos y disponibilidad de
  stock en cotizaciones.
- `../../screens/sales-quote-detail/`: reapertura desde lista/perfil, estados y
  navegacion de retorno contextual.
- `returns/1.return-business.spec.md` y `returns/2.database-contract.spec.md`:
  reglas, ownership cross-module, transaccion e inventario/finanzas de
  devoluciones; la segunda define matriz pgTAP obligatoria.
- `../../screens/sales-return-form/`: contrato UX/API de captura y confirmacion
  (bloqueado hasta implementar los contratos de Sales, Inventory y Payments).
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
- `customer-management/5.ux-ui-roadmap.md`: hoja de ruta UX/UI transversal para
  lista, formulario y perfil de clientes.
- `customer-management/6.customer-business-db.spec.md`: reglas de negocio y
  contrato DB de Clientes, con matriz de cobertura pgTAP.
- `shipping/1.customer-shipping.spec.md`: borrador de envio, guias y rotulos.

## Regla para Clientes

**Las preguntas abiertas quedaron resueltas el 2026-10-03.** El registro
canonico de las 44 decisiones esta en
`customer-management/0.open-questions.md` (seccion B, decisiones 20 a 44).

El rediseño de Clientes ya puede implementarse. Antes de hacerlo hay que leer
ese registro: fija datos fiscales, identificacion, geografia, envio, rankings,
alertas del perfil y la estructura de la guia de carga.

La UX de lista, formulario y perfil se ejecuta como un solo cambio de pantallas.
Las reglas persistentes y sus pruebas pgTAP se especifican por separado en
`customer-management/6.customer-business-db.spec.md`; la UX debe consumir ese
contrato y no mezclar cambios de migraciones/RPC en el cambio de pantallas.

Quedan sueltas solo dos preguntas menores del PIN de aprobacion (longitud y
modo de entrega), en
`../authorization/1.one-time-pin-approval.spec.md`.
