import '../entities/audit_entry.dart';
import '../entities/inventory_transaction.dart';
import '../entities/inventory_balance.dart';
import '../entities/inventory_document.dart';
import '../entities/inventory_reservation.dart';
import '../entities/inventory_count.dart';
import '../../api/inventory_commands.dart';
import '../entities/warehouse.dart';

abstract interface class InventoryRepository {
  Future<List<InventoryTransaction>> getTransactions({String? productId});
  Future<List<Warehouse>> getWarehouses({bool activeOnly = true});
  Future<List<InventoryBalance>> getLocationBalances({String? productId});
  Future<List<InventoryDocument>> getDocuments();
  Future<InventoryDocument?> getDocument(String id);
  Future<InventoryDocument> createAndConfirmDocument(
    InventoryDocumentCommand command,
  );
  Future<InventoryTransaction> addTransaction({
    required String productId,
    required int quantity,
    required InventoryReason reason,
    required String locationId,
    String? notes,
  });
  Future<InventoryTransaction> reverseTransaction(
    InventoryTransaction original, {
    required String notes,
  });
  Future<List<AuditEntry>> getAuditEntries({
    String? tableName,
    String? recordId,
  });
  Future<Warehouse> saveWarehouse({
    String? id,
    required String code,
    required String name,
  });
  Future<InventoryLocation> saveLocation({
    String? id,
    required String warehouseId,
    required String code,
    required String name,
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
  Future<List<InventoryReservation>> getReservations();
  Future<InventoryCount> createCount(String warehouseId);
  Future<void> confirmCount(String countId);
  Future<void> dispatchTransfer(String documentId);
  Future<void> markTransferInTransit(String documentId);
  Future<void> receiveTransfer(String documentId);

  // Draft documents
  Future<InventoryDocument> confirmDocument(String documentId);
  Future<void> dispatchDocument(String documentId);
}
