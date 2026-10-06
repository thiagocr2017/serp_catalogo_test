import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/inventory/api/inventory_dtos.dart';
import 'package:serp/modules/inventory/di/inventory_providers.dart';
import 'package:serp/modules/inventory/presentation/pages/audit_page.dart';

void main() {
  testWidgets('auditoria identifica recurso y muestra quien/cuando', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/audit',
      routes: [
        GoRoute(path: '/audit', builder: (context, state) => const AuditPage()),
        GoRoute(
          path: '/products/product-1',
          builder: (context, state) => const Scaffold(body: Text('Producto')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          auditEntriesProvider.overrideWith(
            (ref) async => [
              AuditEntryDto(
                id: 'audit-1',
                tableName: 'products',
                recordId: 'product-1',
                operation: 'INSERT',
                createdAt: DateTime(2026, 10, 5, 13, 7),
                fieldName: 'name',
                newValue: 'Set demo',
                actorName: 'Ana',
                deviceName: 'Mac oficina',
                resourceLabel: 'HJ300-1 · Set demo',
                resourcePath: '/products/product-1',
              ),
            ],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Se creó un producto HJ300-1 · Set demo'), findsOneWidget);
    expect(find.textContaining('Ana · Mac oficina'), findsOneWidget);
    expect(find.textContaining('05/10/2026 13:07'), findsOneWidget);
    await tester.tap(find.byTooltip('Abrir elemento afectado'));
    await tester.pumpAndSettle();
    expect(find.text('Producto'), findsOneWidget);
  });
}
