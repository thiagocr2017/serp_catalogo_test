import 'package:uuid/uuid.dart';

import '../../domain/entities/audit_entry.dart';
import '../../domain/entities/inventory_transaction.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../data_sources/supabase_inventory_data_source.dart';

class SupabaseInventoryRepository implements InventoryRepository {
  const SupabaseInventoryRepository(this._source);
  final SupabaseInventoryDataSource _source;

  static const _reasonToDatabase = {
    InventoryReason.initialStock: 'INITIAL_STOCK',
    InventoryReason.purchase: 'PURCHASE',
    InventoryReason.sale: 'SALE',
    InventoryReason.adjustment: 'ADJUSTMENT',
    InventoryReason.returnItem: 'RETURN',
    InventoryReason.reversal: 'REVERSAL',
  };

  @override
  Future<List<InventoryTransaction>> getTransactions({
    String? productId,
  }) async =>
      (await _source.transactions(productId: productId))
          .map(_transaction)
          .toList();

  @override
  Future<InventoryTransaction> addTransaction({
    required String productId,
    required int quantity,
    required InventoryReason reason,
    String? notes,
  }) async {
    final row = await _source.insertTransaction({
      'id': const Uuid().v4(),
      'product_id': productId,
      'quantity': quantity,
      'reason': _reasonToDatabase[reason],
      'notes': notes,
      'actor_name': 'Desktop local',
      'device_name': 'SERP Desktop',
      'device_identifier': 'local-device',
    });
    return _transaction(row);
  }

  @override
  Future<InventoryTransaction> reverseTransaction(
    InventoryTransaction original, {
    required String notes,
  }) async {
    final row = await _source.insertTransaction({
      'id': const Uuid().v4(),
      'product_id': original.productId,
      'quantity': -original.quantity,
      'reason': 'REVERSAL',
      'reversal_of_transaction_id': original.id,
      'notes': notes,
      'actor_name': 'Desktop local',
      'device_name': 'SERP Desktop',
      'device_identifier': 'local-device',
    });
    return _transaction(row);
  }

  @override
  Future<List<AuditEntry>> getAuditEntries({
    String? tableName,
    String? recordId,
  }) async => (await _source.audit(tableName: tableName, recordId: recordId))
      .map(
        (row) => AuditEntry(
          id: row['id'] as String,
          tableName: row['table_name'] as String,
          recordId: row['record_id'] as String,
          operation: row['operation'] as String,
          fieldName: row['field_name'] as String? ?? '',
          oldValue: row['old_value'] as String?,
          newValue: row['new_value'] as String?,
          actorName: row['actor_name'] as String?,
          deviceName: row['device_name'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
      )
      .toList();

  InventoryTransaction _transaction(Map<String, dynamic> row) =>
      InventoryTransaction(
        id: row['id'] as String,
        productId: row['product_id'] as String,
        quantity: row['quantity'] as int,
        reason: switch (row['reason'] as String) {
          'INITIAL_STOCK' => InventoryReason.initialStock,
          'PURCHASE' => InventoryReason.purchase,
          'SALE' => InventoryReason.sale,
          'ADJUSTMENT' => InventoryReason.adjustment,
          'RETURN' => InventoryReason.returnItem,
          _ => InventoryReason.reversal,
        },
        notes: row['notes'] as String?,
        reversalOfTransactionId: row['reversal_of_transaction_id'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
}
