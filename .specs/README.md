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
├── modules/
│   └── <module>/
├── refactors/
│   └── <nn>-<topic>.md
└── screens/
    └── <screen-or-form>/
        ├── 1.requirements.spec.md
        ├── 2.technical-plan.md
        ├── 3.tasks.md
        └── 4.tests.spec.md
```

## Regla de uso

- Cambios de negocio: actualizar o crear spec en `modules/<module>/`.
- Cambios de pantalla/formulario: actualizar o crear spec en `screens/<screen>/`.
- Refactorizaciones necesarias: crear spec separada de refactorizacion en
  `refactors/`. Una spec de feature no esconde cambios de arquitectura.
- Pruebas: toda pantalla o formulario debe tener `4.tests.spec.md`.

## Specs de refactorizacion activas

- `refactors/01-document-consistency.md`: correccion de contradicciones entre
  la documentacion de referencia y el estado real del codigo.
- `refactors/02-tech-debt-plan.md`: plan por fases de la deuda tecnica, con
  dependencias y decisiones pendientes.
- `refactors/03-public-dto-migration.md`: migracion de entidades y repositorios
  expuestos a DTO publicos estables.

Los SDD historicos de la raiz siguen siendo referencia mientras se migra su
contenido de forma organica a estas specs.
