import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/audit_entry.dart';
import '../domain/entities/inventory_transaction.dart';

export '../domain/entities/audit_entry.dart';
export '../domain/entities/inventory_transaction.dart';

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

  Future<List<AuditEntry>> getAuditEntries({
    String? tableName,
    String? recordId,
  });
}
