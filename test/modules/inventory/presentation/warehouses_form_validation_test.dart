import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/inventory/di/inventory_providers.dart';
import 'package:serp/modules/inventory/domain/entities/audit_entry.dart';
import 'package:serp/modules/inventory/domain/entities/inventory_balance.dart';
import 'package:serp/modules/inventory/domain/entities/inventory_count.dart';
import 'package:serp/modules/inventory/domain/entities/inventory_document.dart';
import 'package:serp/modules/inventory/domain/entities/inventory_reservation.dart';
import 'package:serp/modules/inventory/domain/entities/inventory_transaction.dart';
import 'package:serp/modules/inventory/domain/entities/warehouse.dart';
import 'package:serp/modules/inventory/domain/repositories/inventory_repository.dart';
import 'package:serp/modules/inventory/api/inventory_commands.dart';
import 'package:serp/modules/inventory/presentation/pages/warehouses_page.dart';

void main() {
  testWidgets('bodega vacia exige correccion antes de guardar', (tester) async {
    final repository = _RecordingInventoryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [inventoryRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: WarehousesPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva bodega'));
    await tester.pumpAndSettle();

    // Verificar que el diálogo está abierto
    expect(find.byType(AlertDialog), findsOneWidget);

    // Intentar guardar sin llenar campos
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    // El diálogo debe seguir abierto (no se guardó)
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Escriba el código.'), findsOneWidget);
    expect(find.text('Escriba el nombre.'), findsOneWidget);
    expect(repository.savedWarehouses, 0);

    // Llenar campos y guardar
    await tester.enterText(find.widgetWithText(TextField, 'Código'), 'BOD-01');
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Bodega Central',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.savedWarehouses, 1);
  });
}

class _RecordingInventoryRepository implements InventoryRepository {
  int savedWarehouses = 0;

  @override
  Future<List<Warehouse>> getWarehouses({bool activeOnly = true}) async =>
      const [
        Warehouse(
          id: 'warehouse-1',
          code: 'BOD-01',
          name: 'Bodega Central',
          isDefault: true,
          isActive: true,
          locations: [],
        ),
      ];

  @override
  Future<Warehouse> saveWarehouse({
    String? id,
    required String code,
    required String name,
  }) async {
    savedWarehouses++;
    return Warehouse(
      id: id ?? 'warehouse-new',
      code: code,
      name: name,
      isDefault: false,
      isActive: true,
    );
  }

  @override
  Future<InventoryLocation> saveLocation({
    String? id,
    required String warehouseId,
    required String code,
    required String name,
  }) async => InventoryLocation(
    id: id ?? 'location-new',
    warehouseId: warehouseId,
    code: code,
    name: name,
    isDefault: false,
    isActive: true,
  );

  @override
  Future<List<InventoryTransaction>> getTransactions({
    String? productId,
  }) async => const [];

  @override
  Future<List<InventoryBalance>> getLocationBalances({
    String? productId,
  }) async => const [];

  @override
  Future<List<InventoryDocument>> getDocuments() async => const [];

  @override
  Future<InventoryDocument?> getDocument(String id) async => null;

  @override
  Future<InventoryDocument> createAndConfirmDocument(
    InventoryDocumentCommand command,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<InventoryTransaction> addTransaction({
    required String productId,
    required int quantity,
    required InventoryReason reason,
    required String locationId,
    String? notes,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<InventoryTransaction> reverseTransaction(
    InventoryTransaction original, {
    required String notes,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<AuditEntry>> getAuditEntries({
    String? tableName,
    String? recordId,
  }) async => const [];

  @override
  Future<InventoryReservation> reserveStock({
    required String productId,
    required String locationId,
    required String orderId,
    required int quantity,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> releaseReservation(String reservationId) async {}

  @override
  Future<void> consumeReservation(String reservationId) async {}

  @override
  Future<List<InventoryReservation>> getReservations() async => const [];

  @override
  Future<InventoryCount> createCount(String warehouseId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> confirmCount(String countId) async {}

  @override
  Future<void> dispatchTransfer(String documentId) async {}

  @override
  Future<void> markTransferInTransit(String documentId) async {}

  @override
  Future<void> receiveTransfer(String documentId) async {}

  @override
  Future<InventoryDocument> confirmDocument(String documentId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> dispatchDocument(String documentId) async {}
}
