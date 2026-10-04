import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/inventory/api/inventory_dtos.dart';
import 'package:serp/modules/inventory/api/transaction_descriptions.dart';

InventoryTransactionDto movement({
  required String id,
  required InventoryReason reason,
  required int quantity,
  String? documentId,
  String? warehouseName,
  String? locationName,
}) => InventoryTransactionDto(
  id: id,
  productId: 'product-1',
  quantity: quantity,
  reason: reason,
  createdAt: DateTime.utc(2026, 1, 1),
  warehouseId: 'warehouse-1',
  locationId: 'location-1',
  warehouseName: warehouseName,
  locationName: locationName,
  documentId: documentId,
);

void main() {
  final outLeg = movement(
    id: 'out',
    reason: InventoryReason.transferOut,
    quantity: -2,
    documentId: 'doc-1',
    warehouseName: 'Principal',
    locationName: 'General',
  );
  final inLeg = movement(
    id: 'in',
    reason: InventoryReason.transferIn,
    quantity: 2,
    documentId: 'doc-1',
    warehouseName: 'Principal',
    locationName: 'Anaquel 424',
  );

  test('transfer legs read as output then input', () {
    expect(
      describeInventoryTransaction(outLeg, [outLeg, inLeg]),
      'Salida de Principal · General → Principal · Anaquel 424',
    );
    expect(
      describeInventoryTransaction(inLeg, [outLeg, inLeg]),
      'Entrada en Principal · Anaquel 424 desde Principal · General',
    );
  });

  test('same document sorts output before input', () {
    final sorted = [inLeg, outLeg]..sort(compareInventoryHistory);
    expect(sorted.map((item) => item.id), ['out', 'in']);
  });

  test('transfer leg without counterpart falls back to single endpoint', () {
    expect(
      describeInventoryTransaction(outLeg, [outLeg]),
      'Salida por traslado desde Principal · General',
    );
    expect(
      describeInventoryTransaction(inLeg, []),
      'Entrada por traslado en Principal · Anaquel 424',
    );
  });

  test('non-transfer reasons mention their place', () {
    final sale = movement(
      id: 'sale',
      reason: InventoryReason.sale,
      quantity: -1,
      warehouseName: 'Principal',
      locationName: 'General',
    );
    expect(
      describeInventoryTransaction(sale, [sale]),
      'Venta despachada desde Principal · General',
    );
  });

  test('missing names degrade gracefully', () {
    final bare = movement(
      id: 'x',
      reason: InventoryReason.adjustment,
      quantity: 1,
    );
    expect(
      describeInventoryTransaction(bare, [bare]),
      'Ajuste en Ubicación no disponible',
    );
    expect(transferCounterpart(bare, [bare]), isNull);
  });
}
