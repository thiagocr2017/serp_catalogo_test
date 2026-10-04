import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'inventory_commands.dart';
import 'inventory_dtos.dart';

export 'inventory_commands.dart';
export 'inventory_dtos.dart';
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
  Future<List<InventoryTransactionDto>> getTransactions({String? productId});

  Future<List<WarehouseDto>> getWarehouses({bool activeOnly = true});

  Future<List<InventoryBalanceDto>> getLocationBalances({String? productId});

  Future<List<InventoryDocumentDto>> getDocuments();

  Future<InventoryDocumentDto?> getDocument(String id);

  Future<InventoryDocumentDto> createAndConfirmDocument(
    InventoryDocumentCommand command,
  );

  Future<List<AuditEntryDto>> getAuditEntries({
    String? tableName,
    String? recordId,
  });

  // Advanced inventory
  Future<InventoryReservationDto> reserveStock({
    required String productId,
    required String locationId,
    required String orderId,
    required int quantity,
  });
  Future<void> releaseReservation(String reservationId);
  Future<void> consumeReservation(String reservationId);
  Future<InventoryCountDto> createCount(String warehouseId);
  Future<void> confirmCount(String countId);
  Future<void> dispatchTransfer(String documentId);
  Future<void> markTransferInTransit(String documentId);
  Future<void> receiveTransfer(String documentId);

  // Draft documents
  Future<InventoryDocumentDto> confirmDocument(String documentId);
  Future<void> dispatchDocument(String documentId);
}
