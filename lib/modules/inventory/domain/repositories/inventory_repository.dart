import '../entities/audit_entry.dart';
import '../entities/inventory_transaction.dart';
import '../entities/inventory_balance.dart';
import '../entities/warehouse.dart';

abstract interface class InventoryRepository {
  Future<List<InventoryTransaction>> getTransactions({String? productId});
  Future<List<Warehouse>> getWarehouses({bool activeOnly = true});
  Future<List<InventoryBalance>> getLocationBalances({String? productId});
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
}
