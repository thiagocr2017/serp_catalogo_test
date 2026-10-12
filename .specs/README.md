# Specs SERP

Este directorio contiene las especificaciones vivas del proyecto. Las specs se
versionan junto al codigo y son el contrato de trabajo para cambios funcionales,
refactorizaciones complejas y pantallas/formularios.

## Estructura

```text
.specs/
├── 00-project-context.md
├── 01-module-contracts.md
├── 02-document-standards.md
├── 03-form-behavior.md
├── 04-sales-payments-contract.md
├── architecture/
│   ├── document-standards.md
│   ├── module-security-contract.md
│   ├── navigation-entrypoints.md
│   ├── navigation-return-context.md
│   ├── list-patterns.md
│   ├── theme-governance.md
│   └── module-structure.md
├── archive/
│   └── verification/
├── database/
│   └── schema-current.md
├── modules/
│   └── <module>/
│       └── demo-data/
│           └── 1.demo-dataset.spec.md
│       └── returns/ (contratos distribuidos por ownership)
├── refactors/
│   └── <nn>-<topic>.md
├── roadmaps/
│   └── <yyyymmdd>-<topic>.md
├── screens/
│   └── <screen-or-form>/
│       ├── 1.requirements.spec.md
│       ├── 2.technical-plan.md
│       ├── 3.tasks.md
│       └── 4.tests.spec.md
└── testing/
    ├── form-coverage.md
    └── e2e.md
```

## Regla de uso

- Cambios de negocio: actualizar o crear spec en `modules/<module>/`.
- Cambios de pantalla/formulario: actualizar o crear spec en `screens/<screen>/`.
- Cambios de arquitectura transversal: actualizar `architecture/`.
- Mejoras UX/UI que cruzan varias pantallas: registrar orden, dependencias y
  decisiones pendientes en `roadmaps/`; los contratos reutilizables viven en
  `architecture/` y cada pantalla conserva su spec de cuatro archivos.
- Toda pantalla principal debe estar vinculada desde el menu lateral; mantener
  `.specs/architecture/navigation-entrypoints.md` y la prueba del shell junto
  con sus rutas y entradas visibles.
- Cambios de esquema, permisos o RPC: actualizar `database/`.
- Cambios de cobertura de formularios: actualizar `testing/form-coverage.md`.
- Refactorizaciones necesarias: crear spec separada de refactorizacion en
  `refactors/`. Una spec de feature no esconde cambios de arquitectura.
- Pruebas: toda pantalla o formulario debe tener `4.tests.spec.md`.
- Pruebas E2E: ampliar por flujos verticales de un modulo en
  `integration_test/`, contra servicios locales reales; registrar setup,
  persistencia, aislamiento y comandos en `.specs/testing/e2e.md`.

## Contratos transversales

- La moneda de referencia de la app (nombre y símbolo) se define en
  `.specs/modules/configuration/sdd-historical.md`; solo Pagos maneja tipo de
  cambio cuando recibe dinero en otra moneda.
- `04-sales-payments-contract.md`: frontera entre `sales` y `payments`.
  Definido y no implementado. Obligatorio antes de crear facturas persistentes
  con aplicaciones de pago.
- `architecture/list-patterns.md`: listas indice, contextuales y de composicion.
- `architecture/search-interaction.md`: busqueda desde tres caracteres,
  restauracion al borrar y debounce remoto compartidos.
- `architecture/theme-governance.md`: fuente unica de tema, tokens y patrones
  visuales compartidos.
- La skill `.opencode/skills/ux-ui-screen-design/SKILL.md` apunta a estos
  contratos y a `lib/shared/theme/` antes de crear o redisenar UI.
- `roadmaps/20261005_ux-ui-improvements.md`: plan transversal priorizado de
  listas, ventas, clientes, configuracion, auditoria, devoluciones y
  consignaciones.
- `roadmaps/20261006-module-readiness.md`: cierre progresivo de las capacidades
  actuales con criterios de persistencia y verificacion por modulo.
- `modules/inventory/document-lifecycle.spec.md`: estados y efectos atomicos
  para traslados diferidos.

- `modules/demo-data/1.demo-dataset.spec.md`: conjunto de datos local amplio,
  sintético, idempotente y exclusivo del modo `TEST`.
- `modules/sales/returns/`: reglas comerciales y contrato DB/pgTAP de
  devoluciones; complementado por `modules/inventory/returns/` para cuarentena
  y `modules/payments/returns/` para liquidacion.

## Specs de refactorizacion activas

- `refactors/01-document-consistency.md`: correccion de contradicciones entre
  la documentacion de referencia y el estado real del codigo.
- `refactors/02-tech-debt-plan.md`: plan por fases de la deuda tecnica, con
  dependencias y decisiones pendientes.
- `refactors/03-public-dto-migration.md`: migracion de entidades y repositorios
  expuestos a DTO publicos estables.
- `refactors/04-block-1b-contract-cleanup.md`: puentes heredados que hay que
  eliminar en el bloque 1B.3.
- `refactors/05-anonymous-access-removal.md`: auditoría y plan gradual para
  retirar acceso de negocio anónimo; etiquetas `seguridad`, `autorizacion`,
  `anon`, `supabase`, `base-de-datos`, `e2e`, `puerta-produccion`,
  `fase-1-identidad`. En progreso; bloqueante para producción y purga hasta
  implementar y probar aprovisionamiento, sesión Auth y bootstrap del primer
  superadministrador. El modelo aprobado excluye registro abierto; la
  configuración local aún no está migrada. El reclamo superadmin por
  dispositivo está revocado.
- `refactors/06-code-cleanup-audit.md`: inventario inicial de código sin uso,
  dependencias candidatas y documentación desactualizada; etiquetas
  `mantenimiento`, `dead-code`, `documentacion-obsoleta`, `dependencias`,
  `limpieza`, `backlog-futuro`.

## Especificaciones de Pantallas y Formularios

- `screens/customer-management/`: Rediseño y gestión integral de Clientes (lista, formulario y perfil).
- `screens/customer-form/`: Formulario específico de alta y edición de cliente.
- `screens/customer-list/`: Catálogo y lista de clientes.
- `screens/customer-import/`: Importación masiva de clientes desde CSV.
- `screens/document-lines-grid/`: Captura de renglones para documentos comerciales.
- `screens/inventory-history/`: histórico de movimientos y búsqueda contextual.
- `screens/promotion-list/`: lista y búsqueda de promociones.
- `screens/customer-profile/`: Perfil 360°, alertas y pestañas de documentos.
- `screens/customer-management/`: Requisitos integrales y criterios de
  coordinación entre lista, formulario y perfil.
- `screens/inventory-document-form/`: Formulario de documentos de inventario.
- `screens/inventory-document-detail/`: Detalle y trazabilidad de documentos de inventario.
- `screens/inventory-documents/`: Lista y transiciones de documentos de inventario.
- `screens/product-form/`: Formulario de creación y edición de productos.
- `screens/product-profile/`: Perfil de producto y presentación adaptable de
  identificadores copiables.
- `screens/product-list/`: Lista de productos y catálogo.
- `screens/catalog-pdf/`: configuración, selección, orden diferido y preview
  del catálogo PDF.
- `screens/sales-commercial-operations/`: Operaciones de documentos comerciales de venta.
- `screens/sales-quote-form/`: Alta y operación rápida de cotizaciones.
- `screens/sales-quote-detail/`: detalle, estados y retorno contextual de cotizaciones.
- `screens/sales-document-details/`: jerarquía visual, datos y navegación de detalles de documentos de venta.
- `screens/sales-return-form/`: captura y liquidación de devoluciones con
  contrato transaccional DB/RPC; incluye E2E de rechazo anónimo y de devolución
  exitosa autenticada. La anulación compensatoria permanece fuera de alcance.

Las rutas citadas en cualquier documento son relativas a la raiz del
repositorio.

Los SDD historicos ya viven dentro de `.specs/modules/<module>/sdd-historical.md`
y quedan como referencia mientras su contenido se migra de forma organica a
specs enfocadas.
