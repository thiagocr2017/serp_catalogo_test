import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/inventory/api/inventory_api.dart';
import 'package:serp/modules/inventory/api/inventory_routes.dart';
import 'package:serp/shared/widgets/desktop_shell_widget.dart';

void main() {
  testWidgets('detalle vuelve a la lista de documentos de inventario', (
    tester,
  ) async {
    final api = _FakeInventoryApi();
    final router = GoRouter(
      initialLocation: '/inventory/documents/document-1',
      routes: [
        ShellRoute(
          builder: (context, state, child) => DesktopShellWidget(
            currentLocation: state.uri.path,
            child: child,
          ),
          routes: inventoryRoutes,
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [inventoryApiProvider.overrideWithValue(api)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('INV-001'), findsOneWidget);
    await tester.tap(find.text('Volver a documentos'));
    await tester.pumpAndSettle();

    expect(find.text('Documentos de inventario'), findsOneWidget);
    expect(find.text('No hay documentos registrados.'), findsOneWidget);
  });
}

class _FakeInventoryApi implements InventoryApi {
  @override
  Future<InventoryDocumentDto?> getDocument(String id) async =>
      InventoryDocumentDto(
        id: 'document-1',
        number: 'INV-001',
        type: InventoryDocumentType.adjustment,
        status: 'CONFIRMED',
        createdAt: DateTime.utc(2026, 1, 1),
      );

  @override
  Future<List<InventoryDocumentDto>> getDocuments() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
