import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/inventory/api/inventory_commands.dart';
import 'package:serp/modules/inventory/domain/entities/inventory_document.dart';

void main() {
  test('document command retains the caller idempotency key and line sign', () {
    const command = InventoryDocumentCommand(
      commandId: 'command-001',
      type: InventoryDocumentType.adjustment,
      lines: [
        InventoryDocumentLineCommand(productId: 'product-001', quantity: -3),
        InventoryDocumentLineCommand(productId: 'product-002', quantity: 8),
      ],
      destinationWarehouseId: 'warehouse-001',
      destinationLocationId: 'location-001',
      notes: 'Conteo inicial',
    );

    expect(command.commandId, 'command-001');
    expect(command.type, InventoryDocumentType.adjustment);
    expect(command.lines.map((line) => line.quantity), [-3, 8]);
    expect(command.destinationLocationId, 'location-001');
  });

  test('document model preserves historical line and location data', () {
    final createdAt = DateTime.utc(2026, 9, 29, 12);
    final document = InventoryDocument(
      id: 'document-001',
      number: 'AJU-00000001',
      type: InventoryDocumentType.adjustment,
      status: 'CONFIRMED',
      createdAt: createdAt,
      originWarehouseName: 'Bodega principal',
      destinationLocationName: 'Ubicación general',
      lines: const [
        InventoryDocumentLine(
          id: 'line-001',
          productId: 'product-001',
          quantity: -2,
          productSku: 'SKU-001',
          productName: 'Producto de prueba',
          notes: 'Corrección',
        ),
      ],
    );

    expect(document.status, 'CONFIRMED');
    expect(document.createdAt, createdAt);
    expect(document.lines.single.quantity, -2);
    expect(document.lines.single.productSku, 'SKU-001');
    expect(document.destinationLocationName, 'Ubicación general');
  });
}
