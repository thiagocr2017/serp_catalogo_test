import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/inventory/api/inventory_api.dart';
import 'package:serp/modules/inventory/presentation/pages/inventory_document_form_page.dart';
import 'package:serp/modules/product/product_module.dart';

void main() {
  testWidgets('rechaza linea sin producto y no ejecuta persistencia', (
    tester,
  ) async {
    final inventory = _InventoryApiFake();
    await _pumpForm(tester, inventory);
    await _showLines(tester);

    await tester.tap(find.text('Confirmar ajuste'));
    await tester.pumpAndSettle();
    expect(inventory.createdCommands, isEmpty);
  });

  testWidgets('confirma ajuste valido y abre su detalle', (tester) async {
    final inventory = _InventoryApiFake();
    await _pumpForm(tester, inventory);
    await _showLines(tester);

    await tester.enterText(_field('Producto'), 'SK');
    await tester.pumpAndSettle();
    expect(find.text('SKU-1 · Producto uno'), findsNothing);

    await tester.enterText(_field('Producto'), 'SKU');
    await tester.pumpAndSettle();
    expect(find.text('SKU-1 · Producto uno'), findsOneWidget);

    await tester.enterText(_field('Producto'), 'SKU-1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('SKU-1 · Producto uno'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Cantidad'), '3');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar ajuste'));
    await tester.pumpAndSettle();

    expect(inventory.createdCommands, hasLength(1));
    final command = inventory.createdCommands.single;
    expect(command.type, InventoryDocumentType.adjustment);
    expect(command.destinationWarehouseId, 'warehouse-1');
    expect(command.destinationLocationId, 'location-1');
    expect(command.lines.single.productId, 'product-1');
    expect(command.lines.single.quantity, 3);
    expect(find.text('Detalle falso'), findsOneWidget);
  });
}

Future<void> _showLines(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -500));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _pumpForm(WidgetTester tester, _InventoryApiFake inventory) async {
  final router = GoRouter(
    initialLocation: '/inventory/documents/new',
    routes: [
      GoRoute(
        path: '/inventory/documents/new',
        builder: (_, _) => const InventoryDocumentFormPage(),
      ),
      GoRoute(
        path: '/inventory/documents/:id',
        builder: (_, _) => const Scaffold(body: Text('Detalle falso')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inventoryApiProvider.overrideWithValue(inventory),
        productApiProvider.overrideWithValue(_ProductApiFake()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Nuevo documento de inventario'), findsOneWidget);
  expect(find.byType(TextField), findsWidgets);
}

class _InventoryApiFake implements InventoryApi {
  final createdCommands = <InventoryDocumentCommand>[];

  @override
  Future<List<WarehouseDto>> getWarehouses({bool activeOnly = true}) async => [
    const WarehouseDto(
      id: 'warehouse-1',
      code: 'BOD-1',
      name: 'Bodega principal',
      isDefault: true,
      isActive: true,
      locations: [
        InventoryLocationDto(
          id: 'location-1',
          warehouseId: 'warehouse-1',
          code: 'GEN',
          name: 'General',
          isDefault: true,
          isActive: true,
        ),
      ],
    ),
  ];

  @override
  Future<List<InventoryBalanceDto>> getLocationBalances({
    String? productId,
  }) async => const [];

  @override
  Future<InventoryDocumentDto> createAndConfirmDocument(
    InventoryDocumentCommand command,
  ) async {
    createdCommands.add(command);
    return InventoryDocumentDto(
      id: 'document-1',
      number: 'AJU-00000001',
      type: command.type,
      status: 'CONFIRMED',
      createdAt: DateTime(2026),
      lines: [
        for (final line in command.lines)
          InventoryDocumentLineDto(
            id: 'line-1',
            productId: line.productId,
            quantity: line.quantity,
          ),
      ],
    );
  }

  @override
  Future<List<InventoryTransactionDto>> getTransactions({
    String? productId,
  }) async => const [];
  @override
  Future<List<InventoryDocumentDto>> getDocuments() async => const [];
  @override
  Future<InventoryDocumentDto?> getDocument(String id) async => null;
  @override
  Future<List<AuditEntryDto>> getAuditEntries({
    String? tableName,
    String? recordId,
  }) async => const [];
  @override
  Future<InventoryReservationDto> reserveStock({
    required String productId,
    required String locationId,
    required String orderId,
    required int quantity,
  }) => throw UnimplementedError();
  @override
  Future<void> releaseReservation(String reservationId) async =>
      throw UnimplementedError();
  @override
  Future<void> consumeReservation(String reservationId) async =>
      throw UnimplementedError();
  @override
  Future<InventoryCountDto> createCount(String warehouseId) =>
      throw UnimplementedError();
  @override
  Future<void> confirmCount(String countId) async => throw UnimplementedError();
  @override
  Future<void> dispatchTransfer(String documentId) async =>
      throw UnimplementedError();
  @override
  Future<void> markTransferInTransit(String documentId) async =>
      throw UnimplementedError();
  @override
  Future<void> receiveTransfer(String documentId) async =>
      throw UnimplementedError();
  @override
  Future<InventoryDocumentDto> confirmDocument(String documentId) =>
      throw UnimplementedError();
  @override
  Future<void> dispatchDocument(String documentId) async =>
      throw UnimplementedError();
}

class _ProductApiFake implements ProductApi {
  static const _product = ProductSummaryDto(
    id: 'product-1',
    sku: 'SKU-1',
    name: 'Producto uno',
    description: 'Producto de prueba',
    currentStock: 8,
  );

  @override
  Future<List<ProductSummaryDto>> listProducts([
    ProductListQuery query = const ProductListQuery(),
  ]) async => const [_product];

  @override
  Future<ProductSummaryDto?> getProductSummary(String id) async => _product;
}
