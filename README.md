# SERP

Aplicación de escritorio Flutter para gestión de productos, inventario base,
promociones, auditoría y generación local de catálogos PDF. Usa Riverpod 3,
GoRouter y una instancia local de Supabase/PostgreSQL como fuente de verdad.

La interfaz utiliza modo oscuro de forma predeterminada. El usuario puede
cambiar entre modo oscuro y claro desde Configuración y la elección se conserva
localmente en el equipo.

## Requisitos

- Flutter estable con soporte para macOS.
- Xcode completo para compilar la aplicación de escritorio.
- Docker Desktop.
- Supabase CLI.

## Puesta en marcha

Desde la raíz del proyecto:

```bash
supabase start
supabase db reset
flutter pub get
flutter run -d macos
```

La aplicación usa por defecto `http://127.0.0.1:54321`. Las migraciones y los
datos de demostración viven en `supabase/migrations/` y `supabase/seed.sql`.

## Validación

```bash
flutter analyze
flutter test
flutter build macos --debug
```

Para generar el catálogo PDF de muestra:

```bash
dart run tool/generate_sample_catalog.dart
```

El archivo se crea en `output/pdf/catalogo_serp_muestra.pdf`. Los catálogos se
generan en la computadora y no se suben a Supabase.

## Arquitectura

Los módulos se encuentran en `lib/modules/` y deben mantener las capas `api`,
`domain`, `data`, `presentation` y `di`. Las pruebas reflejan esa estructura en
`test/modules/`.

Estado actual:

- Productos: funcional y comunicado con otros módulos mediante API pública.
- Inventario y auditoría: funcionales y comunicados mediante API pública.
- Ventas: estructura modular inicial completa; administra agentes del catálogo.
- Configuración: área transitoria dentro de `core`.

Documentación:

- [`MODULE_STRUCTURE.md`](MODULE_STRUCTURE.md): convenciones y deuda técnica.
- [`SDD_Modulo_Productos.md`](SDD_Modulo_Productos.md): productos, categorías,
  promociones, importación/exportación y catálogo PDF.
- [`SDD_Modulo_Inventario.md`](SDD_Modulo_Inventario.md): movimientos, stock y
  auditoría.
- [`SDD_Modulo_Ventas.md`](SDD_Modulo_Ventas.md): agentes implementados y
  alcance futuro de ventas.
