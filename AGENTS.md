# AGENTS.md

## Project Overview

Flutter desktop app (macOS) for product management, inventory, promotions, audit, and local PDF catalog generation. Uses Riverpod 3, GoRouter, and a local Supabase/PostgreSQL instance as the source of truth.

## Setup & Commands

```bash
supabase start          # Start local Supabase (required before running app)
supabase db reset       # Reset DB with migrations + seed data
flutter pub get         # Install dependencies
flutter run -d macos    # Run the app
```

Validation:
```bash
flutter analyze
flutter test
flutter build macos --debug
```

Generate sample PDF catalog:
```bash
dart run tool/generate_sample_catalog.dart
# Output: output/pdf/catalogo_serp_muestra.pdf
```

Run a single module's tests:
```bash
flutter test test/modules/product
```

## Architecture

### Module Structure

Each module lives in `lib/modules/<name>/` with strict layer separation:

```
<name>/
├── api/              # Public contracts only (facades, DTOs, routes)
├── domain/           # Pure business logic (entities, use_cases, repository interfaces)
├── data/             # Data access (data_sources, models, mappers, repository impls)
├── presentation/     # UI (controllers, pages, widgets)
├── di/               # Riverpod dependency registration
└── <name>_module.dart  # Public index — the ONLY import other modules may use
```

### Module Boundaries (Critical)

- **Cross-module imports are forbidden** except through `<name>_module.dart` (the public API index).
- Never import another module's `data/`, `domain/`, `di/`, `presentation/`, or `services/`.
- `main.dart` is the sole composition root — it constructs implementations and injects them via Riverpod `ProviderScope` overrides.
- `core/` and `shared/` are not business modules; they hold genuinely reusable technical capabilities only.

### Current Modules

| Module | Status |
|---|---|
| `product` | Functional, public API |
| `inventory` | Functional, public API |
| `configuration` | Functional, public API |
| `sales` | Partial — agents and full customer CRUD functional; commercial documents (quotes, orders, invoices, returns, consignations) have data model + RPC but read-only UI |
| `payments` | Partial — base implementation wired in `main.dart`; reads work, writes do not persist yet (data layer hits `SELECT`-only tables instead of its RPCs). Narrower scope than `SDD_Modulo_Pagos.md` |
| `authorization` | Spec draft only (`one-time-pin-approval`), not implemented |

Before trusting a module's status, verify it against `lib/modules/<name>/` and
`.specs/`. Status tables drift; the code does not.

### Core Directories

- `core/configuration/` — Local app config (Supabase URL/key, theme preference)
- `core/navigation/` — GoRouter setup
- `core/offline/` — Local offline command queue and sync service
- `core/audit/`, `core/database/`, `core/device/`, `core/errors/`, `core/identity/`, `core/utilities/`
- `shared/navigation/`, `shared/theme/`, `shared/widgets/` — theme and reusable visual components (not business modules)

## Conventions

- Module names: `snake_case`, singular (e.g., `product`, `inventory`)
- Technical identifiers (tables, columns, variables): English
- UI text and functional docs: Spanish
- Dark mode is the default; theme preference is local (not in Supabase)
- Linting: `flutter_lints` via `analysis_options.yaml`
- When recommending an approach to the user, include the basic reason and
  tradeoff. Do not recommend "do X" without briefly explaining why it fits and
  what consequence it has compared with the likely alternative.

## Testing

Tests mirror `lib/` structure under `test/`:
```
test/modules/{product,inventory,sales,configuration,payments}/
test/core/
test/shared/
```

Database behaviour is covered separately by pgTAP under `supabase/tests/`
(`database/` for contracts and privileges, `concurrency/` for idempotency).
Run those before and after any change to migrations, RPCs, RLS, or grants.

## Spec-Driven Development

The project uses `.specs/` as the living source for feature, screen, form, and
refactor specifications. Specs are versioned with the code and must be updated
with the implementation they describe.

Root specs:
- `.specs/00-project-context.md` — technology stack, constraints, global
  architecture, and forbidden patterns.
- `.specs/01-module-contracts.md` — public API boundaries, allowed
  communication, security, audit, and cross-module rules.
- `.specs/02-document-standards.md` — document output contract for A4 PDF,
  80mm thermal ticket, and ESC/POS direct printing.

Feature/screen specs:
```
.specs/screens/<screen-or-form>/
├── 1.requirements.spec.md  # WHAT and WHY: business behavior and scope
├── 2.technical-plan.md     # HOW: files, APIs, risks, compatibility
├── 3.tasks.md              # STEP BY STEP: small actionable tasks
└── 4.tests.spec.md         # TEST CONTRACT: required coverage for the screen
```

Module-level business rules live under `.specs/modules/<module>/`. Existing
`SDD_Modulo_*.md` files are historical references while their content is
migrated organically into `.specs/`.

Rules:
- Before changing a screen, form, feature, or complex refactor, read the
  relevant `.specs/` files first.
- If no spec exists for the touched screen/form, create the four-file spec set
  before or alongside the implementation.
- Specs must be binary and verifiable: describe concrete inputs, outputs,
  errors, states, and testable acceptance criteria.
- Do not hide architecture changes inside a feature spec. Create a separate
  refactor spec when architecture must change first.
- For legacy areas, write characterization tests before modifying behavior when
  the existing rules are not fully specified.
- After finishing a task, document discoveries only for the area touched. Do not
  attempt to rewrite the whole legacy SDD at once.
- Pull requests or finished tasks that change behavior should include the spec
  update and the code/test update together.

Screen/form test specs:
- Every screen or form spec must include `4.tests.spec.md`.
- A form is not "ready" unless tests cover its real operation and validation
  failures.
- CRUD forms require create, read/load, update, and delete/deactivate coverage
  when those operations exist.
- CRU forms require create, read/load, and update coverage.
- Specific-operation forms require tests for their actual operation, such as
  confirm, import, export, calculate, select, configure, or print.
- Invalid input must keep the form open and must not execute persistence
  commands.

## Document Output Standard

Every confirmed document must support three outputs (defined in `DOCUMENT_STANDARDS.md`):
1. **A4 PDF** — formal, email, conventional printing
2. **80mm thermal ticket** — fast delivery
3. **ESC/POS direct** — Bluetooth/USB thermal printer (no PDF intermediate)

Initial printer profile: Rongta RPP300 (80mm, 72mm printable, 203dpi).

## Skills

Project skills live in `.opencode/skills/<skill-id>/`. They are discoverable by
the agent harness; load them explicitly before doing work that matches their
scope instead of improvising from memory.

### `ux-ui-screen-design` — screen design and redesign

**Load it (skill tool, id `ux-ui-screen-design`) whenever you:**
- create a new screen, form, list, detail view, or dashboard;
- redesign or restructure an existing screen;
- write or update `1.requirements.spec.md` / `2.technical-plan.md` for a screen;
- audit usability, accessibility, or visual hierarchy of existing UI;
- review a change that touches `lib/**/presentation/`.

**Do not load it** for backend-only, migration-only, or infrastructure work.

**What it provides:**

| Resource | Use it for |
|---|---|
| `checklist-new-screen.md` | Gate for a brand-new screen |
| `checklist-redesign.md` | Gate for reworking an existing screen |
| `templates/screen-spec-template.md` | Structure for `.specs/screens/*/1.requirements.spec.md` |
| `templates/redesign-audit-template.md` | Before/after audit of an existing screen |
| `templates/usability-test-script.md` | Script when validating a screen with a user |
| `references/` (15 files) | color-system, spacing-scale, visual-hierarchy, ui-patterns, interaction-patterns, form-design, error-states, loading-states, accessibility, iconography, motion-principles, anti-patterns, screen-anatomy, responsive-breakpoints, ux-principles |
| `scripts/ux-audit.sh` | Fast UX audit of a screen against `checklist-new-screen.md` |
| `scripts/contrast-check.sh` | WCAG contrast verification between a foreground/background pair |

Executable checks (use them instead of eyeballing):

```bash
.opencode/skills/ux-ui-screen-design/scripts/ux-audit.sh --screen "lib/modules/sales/presentation/pages/customers_page.dart"
.opencode/skills/ux-ui-screen-design/scripts/contrast-check.sh --fg "#1976D2" --bg "#FFFFFF"
```

`ux-audit.sh` picks its checks from the file extension: `.dart` runs the
Flutter profile (widget, `ColorScheme`, semantics/labels, loading and error
states, form labels and focus, **no cross-module internal imports**, test file
under `test/`), while `.tsx`/`.jsx`/`.js`/`.ts` keep the original React checks.
An unexpected extension only runs the common file checks. `contrast-check.sh`
is framework-agnostic.

Recommended workflow for a new screen: `references/screen-anatomy.md` +
`checklist-new-screen.md` → `templates/screen-spec-template.md` → build →
`scripts/ux-audit.sh` → `references/accessibility.md` +
`scripts/contrast-check.sh`. For a redesign, start with
`templates/redesign-audit-template.md` and gate with `checklist-redesign.md`.

**Rules:**
- A screen spec produced with this skill must still satisfy the four-file spec
  set in `.specs/screens/<screen>/` and the "form ready" contract in
  `DOCUMENT_STANDARDS.md` §12. The skill improves UX quality; it does not
  replace the test contract in `4.tests.spec.md`.
- UX recommendations must respect module boundaries: a screen may only consume
  its own module's internals plus other modules' `<name>_module.dart` exports.
- When the skill's guidance conflicts with `.specs/` or `DOCUMENT_STANDARDS.md`,
  the project spec wins. Record the conflict in the screen's spec instead of
  silently picking one.
- Dark mode is the default; use `ColorScheme` unless a semantic color needs
  explicit contrast.

## Key Documentation

- [`.specs/`](.specs/README.md) — Living SDD/spec-driven workflow
- [`.specs/refactors/`](.specs/refactors/01-document-consistency.md) — Active refactor specs: document consistency and tech-debt plan
- [`.opencode/skills/`](.opencode/skills/ux-ui-screen-design/SKILL.md) — Project skills (see the Skills section above)
- [`MODULE_STRUCTURE.md`](MODULE_STRUCTURE.md) — Module conventions and technical debt
- [`MODULE_SECURITY_CONTRACT.md`](MODULE_SECURITY_CONTRACT.md) — Mandatory inter-module communication, security, and audit rules
- [`DOCUMENT_STANDARDS.md`](DOCUMENT_STANDARDS.md) — Cross-cutting document output rules
- [`SDD_Modulo_*.md`](SDD_Modulo_Productos.md) — Per-module design docs (Productos, Inventario, Ventas, Configuracion, Pagos)
