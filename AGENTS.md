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
| `sales` | Initial structure (catalog agents) |
| `payments` | Design approved, not yet implemented |

### Core Directories

- `core/configuration/` — Local app config (Supabase URL/key, theme preference)
- `core/navigation/` — GoRouter setup
- `core/audit/`, `core/database/`, `core/device/`, `core/errors/`, `core/identity/`, `core/utilities/`

## Conventions

- Module names: `snake_case`, singular (e.g., `product`, `inventory`)
- Technical identifiers (tables, columns, variables): English
- UI text and functional docs: Spanish
- Dark mode is the default; theme preference is local (not in Supabase)
- Linting: `flutter_lints` via `analysis_options.yaml`

## Testing

Tests mirror `lib/` structure under `test/`:
```
test/modules/{product,inventory,sales,configuration}/
test/core/
test/shared/
```

## Document Output Standard

Every confirmed document must support three outputs (defined in `DOCUMENT_STANDARDS.md`):
1. **A4 PDF** — formal, email, conventional printing
2. **80mm thermal ticket** — fast delivery
3. **ESC/POS direct** — Bluetooth/USB thermal printer (no PDF intermediate)

Initial printer profile: Rongta RPP300 (80mm, 72mm printable, 203dpi).

## Key Documentation

- [`MODULE_STRUCTURE.md`](MODULE_STRUCTURE.md) — Module conventions and technical debt
- [`MODULE_SECURITY_CONTRACT.md`](MODULE_SECURITY_CONTRACT.md) — Mandatory inter-module communication, security, and audit rules
- [`DOCUMENT_STANDARDS.md`](DOCUMENT_STANDARDS.md) — Cross-cutting document output rules
- [`SDD_Modulo_*.md`](SDD_Modulo_Productos.md) — Per-module design docs (Productos, Inventario, Ventas, Configuracion, Pagos)
