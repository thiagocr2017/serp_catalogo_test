import '../domain/entities/audit_entry.dart';
import '../domain/entities/inventory_transaction.dart';

abstract interface class InventoryApi {
  Future<List<InventoryTransaction>> getTransactions({String? productId});

  Future<List<AuditEntry>> getAuditEntries({
    String? tableName,
    String? recordId,
  });
}
