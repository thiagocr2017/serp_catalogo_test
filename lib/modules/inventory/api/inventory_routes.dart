import 'package:go_router/go_router.dart';

import '../presentation/pages/audit_page.dart';
import '../presentation/pages/inventory_page.dart';
import '../presentation/pages/warehouses_page.dart';

final List<RouteBase> inventoryRoutes = [
  GoRoute(
    path: '/inventory',
    builder: (context, state) => const InventoryPage(),
  ),
  GoRoute(
    path: '/inventory/warehouses',
    builder: (context, state) => const WarehousesPage(),
  ),
  GoRoute(path: '/audit', builder: (context, state) => const AuditPage()),
];
