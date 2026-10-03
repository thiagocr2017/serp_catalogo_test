export 'api/inventory_api.dart';
export 'api/inventory_routes.dart';
// No exportar di/inventory_providers.dart: MODULE_SECURITY_CONTRACT.md §3 prohíbe
// exponer providers internos de Riverpod. main.dart, como raíz de composición,
// importa ese archivo directamente.
