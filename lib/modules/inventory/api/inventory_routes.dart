import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../presentation/pages/audit_page.dart';
import '../presentation/pages/inventory_page.dart';
import '../presentation/pages/inventory_document_form_page.dart';
import '../presentation/pages/inventory_document_page.dart';
import '../presentation/pages/warehouses_page.dart';

final List<RouteBase> inventoryRoutes = [
  GoRoute(
    path: '/inventory',
    builder: (context, state) {
      final productId = state.uri.queryParameters['productId'];
      return InventoryPage(
        key: ValueKey('inventory:${productId ?? ''}'),
        productId: productId,
        productSku: state.uri.queryParameters['sku'],
      );
    },
  ),
  GoRoute(
    path: '/inventory/warehouses',
    builder: (context, state) => const WarehousesPage(),
  ),
  GoRoute(
    path: '/inventory/documents/new',
    builder: (context, state) => const InventoryDocumentFormPage(),
  ),
  GoRoute(
    path: '/inventory/documents/:id',
    builder: (context, state) =>
        InventoryDocumentPage(documentId: state.pathParameters['id']!),
  ),
  GoRoute(path: '/audit', builder: (context, state) => const AuditPage()),
];
