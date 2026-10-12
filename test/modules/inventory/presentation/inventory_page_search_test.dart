import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/inventory/api/inventory_dtos.dart';
import 'package:serp/modules/inventory/di/inventory_providers.dart';
import 'package:serp/modules/inventory/presentation/pages/inventory_page.dart';

void main() {
  testWidgets('historico busca desde tres caracteres y limpia debajo', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/inventory',
      routes: [
        GoRoute(path: '/inventory', builder: (_, _) => const InventoryPage()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryTransactionsProvider.overrideWith(
            (ref) async => [
              InventoryTransactionDto(
                id: 'one',
                productId: 'one',
                productSku: 'ABC-1',
                quantity: 2,
                reason: InventoryReason.adjustment,
                warehouseId: 'warehouse',
                locationId: 'location',
                createdAt: DateTime(2026),
                documentNumber: 'ADJ-1',
              ),
              InventoryTransactionDto(
                id: 'two',
                productId: 'two',
                productSku: 'XYZ-2',
                quantity: -4,
                reason: InventoryReason.adjustment,
                warehouseId: 'warehouse',
                locationId: 'location',
                createdAt: DateTime(2026, 1, 2),
                documentNumber: 'ADJ-2',
              ),
            ],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
    final movementRows = tester.widgetList<ListTile>(find.byType(ListTile));
    final themeColors = Theme.of(tester.element(find.byType(ListTile).first))
        .colorScheme;
    for (final row in movementRows) {
      final indicator = row.leading! as Container;
      final decoration = indicator.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, isNull);
      expect(decoration.border, isA<Border>());
      expect((decoration.border! as Border).top.width, 1.5);
      final icon = indicator.child! as Center;
      expect((icon.child! as Icon).color, themeColors.onSurfaceVariant);
    }

    final search = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Buscar movimientos',
    );
    await tester.enterText(search, 'XY');
    await tester.pumpAndSettle();
    expect(find.textContaining('ABC-1'), findsOneWidget);
    expect(find.textContaining('XYZ-2'), findsOneWidget);

    await tester.enterText(search, 'XYZ');
    await tester.pumpAndSettle();
    expect(find.textContaining('ABC-1'), findsNothing);
    expect(find.textContaining('XYZ-2'), findsOneWidget);

    await tester.enterText(search, 'XY');
    await tester.pumpAndSettle();
    expect(find.textContaining('ABC-1'), findsOneWidget);
    expect(find.textContaining('XYZ-2'), findsOneWidget);
  });
}
