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
- Inventario y auditoría: funcionales y comunicados mediante API pública, con
  bodegas, ubicaciones, saldos por ubicación y comandos idempotentes.
- Ventas: parcial. Agentes y clientes funcionales (CRUD completo de clientes con
  contactos). Cotizaciones, pedidos, facturas, devoluciones y consignaciones
  tienen modelo de datos y RPC, pero sus pantallas son listas de solo lectura.
- Configuración: funcional y expuesta mediante API pública; administra empresa,
  catálogo, presentaciones de producto y transportes.
- Pagos y Recibos: funcional en su alcance actual — pagos con componentes,
  confirmación y anulación, métodos de pago, cuentas monetarias, gastos,
  traslados entre cuentas y reembolsos. Las escrituras van por las RPC
  `SECURITY DEFINER` del módulo. El alcance es más estrecho que
  el SDD histórico de pagos; ver `.specs/modules/payments/1.status.spec.md`.
- Autorización: solo existe el borrador de especificación del PIN de un solo
  uso; no está implementado.

Documentación:

- [`.specs/README.md`](.specs/README.md): índice de especificaciones vivas.
- [`.specs/architecture/module-structure.md`](.specs/architecture/module-structure.md):
  convenciones y deuda técnica.
- [`.specs/architecture/module-security-contract.md`](.specs/architecture/module-security-contract.md):
  comunicación,
  exposición, transacciones y seguridad obligatorias entre módulos.
- [`.specs/architecture/document-standards.md`](.specs/architecture/document-standards.md):
  reglas comunes para
  documentos operativos con PDF A4, ticket térmico de 80 mm e impresión
  ESC/POS directa por Bluetooth o USB. El catálogo comercial de Productos se
  genera sólo como PDF.
- [`.specs/testing/form-coverage.md`](.specs/testing/form-coverage.md): registro de
  formularios, operación esperada y estado de pruebas de operación/validación.
- [`.specs/modules/product/sdd-historical.md`](.specs/modules/product/sdd-historical.md):
  productos, categorías,
  promociones, importación/exportación y catálogo PDF.
- [`.specs/modules/inventory/sdd-historical.md`](.specs/modules/inventory/sdd-historical.md):
  movimientos, stock y
  auditoría.
- [`.specs/modules/sales/sdd-historical.md`](.specs/modules/sales/sdd-historical.md):
  agentes implementados y
  alcance futuro de ventas.
- [`.specs/modules/configuration/sdd-historical.md`](.specs/modules/configuration/sdd-historical.md):
  parámetros de
  empresa, catálogo, presentaciones y límites administrativos.
- [`.specs/modules/payments/sdd-historical.md`](.specs/modules/payments/sdd-historical.md):
  cobros, anticipos, créditos,
  recibos, cuentas monetarias, gastos, reembolsos y operación offline.
