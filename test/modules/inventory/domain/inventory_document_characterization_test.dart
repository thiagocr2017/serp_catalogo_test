import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/device/device_identity.dart';
import 'package:serp/modules/inventory/api/inventory_commands.dart';
import 'package:serp/modules/inventory/data/data_sources/supabase_inventory_data_source.dart';
import 'package:serp/modules/inventory/data/repositories/supabase_inventory_repository.dart';
import 'package:serp/modules/inventory/domain/entities/inventory_document.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _unusedClient = SupabaseClient('http://localhost:54321', 'test-key');

class _RecordingInventoryDataSource extends SupabaseInventoryDataSource {
  _RecordingInventoryDataSource() : super(_unusedClient);

  Map<String, dynamic>? parameters;

  @override
  Future<Map<String, dynamic>> createAndConfirmDocument(
    Map<String, dynamic> values,
  ) async {
    parameters = values;
    return {
      'id': 'document-001',
      'document_number': 'TRA-00000001',
      'document_type': values['p_document_type'],
      'status': 'CONFIRMED',
      'created_at': '2026-09-29T12:00:00.000Z',
      'origin_warehouse': {'name': 'Origen'},
      'origin_location': {'name': 'A-01'},
      'destination_warehouse': {'name': 'Destino'},
      'destination_location': {'name': 'B-01'},
      'external_reference': values['p_external_reference'],
      'notes': values['p_notes'],
      'inventory_document_lines': [
        for (final line in values['p_lines'] as List<dynamic>)
          {
            'id': 'line-${line['product_id']}',
            'product_id': line['product_id'],
            'quantity': line['quantity'],
            'notes': line['notes'],
            'products': {
              'sku': 'SKU-${line['product_id']}',
              'name': 'Producto ${line['product_id']}',
            },
          },
      ],
    };
  }
}

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

  test('zero quantities are retained by current command DTOs', () {
    const command = InventoryDocumentCommand(
      commandId: 'zero-command',
      type: InventoryDocumentType.adjustment,
      destinationLocationId: 'location-001',
      lines: [
        InventoryDocumentLineCommand(productId: 'product-001', quantity: 0),
      ],
    );

    expect(command.lines.single.quantity, 0);
  });

  test(
    'repository serializes a transfer command and maps its returned lines',
    () async {
      final source = _RecordingInventoryDataSource();
      final repository = SupabaseInventoryRepository(
        source,
        const DeviceIdentity(
          name: 'Equipo de prueba',
          identifier: 'device-001',
        ),
      );
      const command = InventoryDocumentCommand(
        commandId: 'transfer-command',
        type: InventoryDocumentType.transfer,
        originWarehouseId: 'warehouse-origin',
        originLocationId: 'location-origin',
        destinationWarehouseId: 'warehouse-destination',
        destinationLocationId: 'location-destination',
        externalReference: 'TR-EXTERNA',
        notes: 'Traslado de caracterización',
        lines: [
          InventoryDocumentLineCommand(
            productId: 'product-a',
            quantity: 4,
            notes: 'Primera línea',
          ),
          InventoryDocumentLineCommand(productId: 'product-b', quantity: 7),
        ],
      );

      final document = await repository.createAndConfirmDocument(command);
      final sent = source.parameters!;

      expect(sent['p_command_id'], 'transfer-command');
      expect(sent['p_document_type'], 'TRANSFER');
      expect(sent['p_origin_warehouse_id'], 'warehouse-origin');
      expect(sent['p_origin_location_id'], 'location-origin');
      expect(sent['p_destination_warehouse_id'], 'warehouse-destination');
      expect(sent['p_destination_location_id'], 'location-destination');
      expect(sent['p_lines'], [
        {'product_id': 'product-a', 'quantity': 4, 'notes': 'Primera línea'},
        {'product_id': 'product-b', 'quantity': 7, 'notes': null},
      ]);
      expect(document.number, 'TRA-00000001');
      expect(document.originLocationName, 'A-01');
      expect(document.destinationLocationName, 'B-01');
      expect(document.lines.map((line) => line.productId), [
        'product-a',
        'product-b',
      ]);
      expect(document.lines.map((line) => line.quantity), [4, 7]);
    },
  );

  test('repository currently serializes adjustment origin from destination warehouse', () async {
    final source = _RecordingInventoryDataSource();
    final repository = SupabaseInventoryRepository(
      source,
      const DeviceIdentity(name: 'Equipo de prueba', identifier: 'device-001'),
    );
    const command = InventoryDocumentCommand(
      commandId: 'adjustment-command',
      type: InventoryDocumentType.adjustment,
      destinationWarehouseId: 'warehouse-adjustment',
      destinationLocationId: 'location-adjustment',
      lines: [
        InventoryDocumentLineCommand(productId: 'product-a', quantity: -2),
      ],
    );

    await repository.createAndConfirmDocument(command);

    expect(source.parameters!['p_origin_warehouse_id'], 'warehouse-adjustment');
    expect(source.parameters!['p_origin_location_id'], isNull);
    expect(
      source.parameters!['p_destination_location_id'],
      'location-adjustment',
    );
  });

  test(
    'reusing the same command object preserves its sequential retry key',
    () {
      const command = InventoryDocumentCommand(
        commandId: 'retry-command',
        type: InventoryDocumentType.adjustment,
        destinationLocationId: 'location-001',
        lines: [
          InventoryDocumentLineCommand(productId: 'product-001', quantity: 1),
        ],
      );

      expect(command.commandId, 'retry-command');
      expect(command.commandId, 'retry-command');
    },
  );
}
