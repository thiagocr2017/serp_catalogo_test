import 'package:uuid/uuid.dart';

import '../../../../core/device/device_identity.dart';
import '../../api/inventory_api.dart';

import '../../domain/repositories/inventory_repository.dart';
import '../data_sources/supabase_inventory_data_source.dart';

class SupabaseInventoryRepository implements InventoryRepository, InventoryApi {
  const SupabaseInventoryRepository(this._source, this._device);
  final SupabaseInventoryDataSource _source;
  final DeviceIdentity _device;

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
      'actor_name': _device.actorName,
      'device_name': _device.name,
      'device_identifier': _device.identifier,
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
      'actor_name': _device.actorName,
      'device_name': _device.name,
      'device_identifier': _device.identifier,
    });
    return _transaction(row);
  }

  @override
  Future<List<AuditEntry>> getAuditEntries({
    String? tableName,
    String? recordId,
  }) async {
    final rows = await _source.audit(tableName: tableName, recordId: recordId);
    final productIds = rows
        .where((row) => row['table_name'] == 'products')
        .map((row) => row['record_id'] as String);
    final categoryIds = rows
        .where((row) => row['table_name'] == 'categories')
        .map((row) => row['record_id'] as String)
        .followedBy(
          rows
              .where((row) => row['field_name'] == 'category_id')
              .expand(
                (row) =>
                    [row['old_value'], row['new_value']].whereType<String>(),
              ),
        );
    final products = await _source.productLabels(productIds);
    final categories = await _source.categoryLabels(categoryIds);
    return rows.map((row) {
      final table = row['table_name'] as String;
      final recordId = row['record_id'] as String;
      return AuditEntry(
        id: row['id'] as String,
        tableName: table,
        recordId: recordId,
        operation: row['operation'] as String,
        fieldName: row['field_name'] as String? ?? '',
        oldValue: row['field_name'] == 'category_id'
            ? categories[row['old_value'] as String?] ??
                  row['old_value'] as String?
            : row['old_value'] as String?,
        newValue: row['field_name'] == 'category_id'
            ? categories[row['new_value'] as String?] ??
                  row['new_value'] as String?
            : row['new_value'] as String?,
        actorName: row['actor_name'] as String?,
        deviceName: row['device_name'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        resourceLabel: table == 'products'
            ? products[recordId]
            : table == 'categories'
            ? categories[recordId]
            : null,
        resourcePath: table == 'products' ? '/products/$recordId' : null,
      );
    }).toList();
  }

  InventoryTransaction _transaction(Map<String, dynamic> row) =>
      InventoryTransaction(
        id: row['id'] as String,
        productId: row['product_id'] as String,
        productSku:
            (row['products'] as Map<String, dynamic>?)?['sku'] as String?,
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
