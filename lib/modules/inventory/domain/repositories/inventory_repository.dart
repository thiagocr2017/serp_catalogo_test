import '../entities/audit_entry.dart';
import '../entities/inventory_transaction.dart';

abstract interface class InventoryRepository {
  Future<List<InventoryTransaction>> getTransactions({String? productId});
  Future<InventoryTransaction> addTransaction({
    required String productId,
    required int quantity,
    required InventoryReason reason,
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
}
