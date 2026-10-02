import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/audit_entry.dart';
import '../domain/entities/inventory_transaction.dart';
import '../domain/entities/inventory_balance.dart';
import '../domain/entities/inventory_document.dart';
import '../domain/entities/inventory_reservation.dart';
import '../domain/entities/inventory_count.dart';
import '../domain/entities/warehouse.dart';
import 'inventory_commands.dart';

export '../domain/entities/audit_entry.dart';
export '../domain/entities/inventory_transaction.dart';
export '../domain/entities/inventory_balance.dart';
export '../domain/entities/inventory_document.dart';
export '../domain/entities/inventory_reservation.dart';
export '../domain/entities/inventory_count.dart';
export '../domain/entities/warehouse.dart';
export 'inventory_commands.dart';
export 'transaction_descriptions.dart';

final inventoryApiProvider = Provider<InventoryApi>(
  (ref) => throw StateError('InventoryApi must be overridden.'),
);

final inventoryDataRevisionProvider =
    NotifierProvider<InventoryDataRevision, int>(InventoryDataRevision.new);

class InventoryDataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void notifyChanged() => state++;
}

abstract interface class InventoryApi {
  Future<List<InventoryTransaction>> getTransactions({String? productId});

  Future<List<Warehouse>> getWarehouses({bool activeOnly = true});

  Future<List<InventoryBalance>> getLocationBalances({String? productId});

  Future<List<InventoryDocument>> getDocuments();

  Future<InventoryDocument?> getDocument(String id);

  Future<InventoryDocument> createAndConfirmDocument(
    InventoryDocumentCommand command,
  );

  Future<List<AuditEntry>> getAuditEntries({
    String? tableName,
    String? recordId,
  });

  // Advanced inventory
  Future<InventoryReservation> reserveStock({
    required String productId,
    required String locationId,
    required String orderId,
    required int quantity,
  });
  Future<void> releaseReservation(String reservationId);
  Future<void> consumeReservation(String reservationId);
  Future<InventoryCount> createCount(String warehouseId);
  Future<void> confirmCount(String countId);
  Future<void> dispatchTransfer(String documentId);
  Future<void> markTransferInTransit(String documentId);
  Future<void> receiveTransfer(String documentId);
}
