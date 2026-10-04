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
│   └── module-structure.md
├── archive/
│   └── verification/
├── database/
│   └── schema-current.md
├── modules/
│   └── <module>/
├── refactors/
│   └── <nn>-<topic>.md
├── screens/
│   └── <screen-or-form>/
│       ├── 1.requirements.spec.md
│       ├── 2.technical-plan.md
│       ├── 3.tasks.md
│       └── 4.tests.spec.md
└── testing/
    └── form-coverage.md
```

## Regla de uso

- Cambios de negocio: actualizar o crear spec en `modules/<module>/`.
- Cambios de pantalla/formulario: actualizar o crear spec en `screens/<screen>/`.
- Cambios de arquitectura transversal: actualizar `architecture/`.
- Cambios de esquema, permisos o RPC: actualizar `database/`.
- Cambios de cobertura de formularios: actualizar `testing/form-coverage.md`.
- Refactorizaciones necesarias: crear spec separada de refactorizacion en
  `refactors/`. Una spec de feature no esconde cambios de arquitectura.
- Pruebas: toda pantalla o formulario debe tener `4.tests.spec.md`.

## Contratos transversales

- `04-sales-payments-contract.md`: frontera entre `sales` y `payments`.
  Definido y no implementado. Obligatorio antes de crear facturas persistentes
  con aplicaciones de pago.

## Specs de refactorizacion activas

- `refactors/01-document-consistency.md`: correccion de contradicciones entre
  la documentacion de referencia y el estado real del codigo.
- `refactors/02-tech-debt-plan.md`: plan por fases de la deuda tecnica, con
  dependencias y decisiones pendientes.
- `refactors/03-public-dto-migration.md`: migracion de entidades y repositorios
  expuestos a DTO publicos estables.
- `refactors/04-block-1b-contract-cleanup.md`: puentes heredados que hay que
  eliminar en el bloque 1B.3.

Las rutas citadas en cualquier documento son relativas a la raiz del
repositorio.

Los SDD historicos ya viven dentro de `.specs/modules/<module>/sdd-historical.md`
y quedan como referencia mientras su contenido se migra de forma organica a
specs enfocadas.
