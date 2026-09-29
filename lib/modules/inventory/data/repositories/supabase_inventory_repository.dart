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
  Future<List<Warehouse>> getWarehouses({bool activeOnly = true}) async =>
      (await _source.warehouses(activeOnly: activeOnly))
          .map(_warehouse)
          .toList();

  @override
  Future<List<InventoryBalance>> getLocationBalances({
    String? productId,
  }) async => (await _source.balances(productId: productId))
      .map(
        (row) => InventoryBalance(
          productId: row['product_id'] as String,
          warehouseId: row['warehouse_id'] as String,
          locationId: row['location_id'] as String,
          quantity: row['quantity'] as int,
          productSku:
              (row['products'] as Map<String, dynamic>?)?['sku'] as String?,
          warehouseName:
              (row['warehouses'] as Map<String, dynamic>?)?['name'] as String?,
          locationName:
              (row['inventory_locations'] as Map<String, dynamic>?)?['name']
                  as String?,
        ),
      )
      .toList();

  @override
  Future<InventoryTransaction> recordTransaction(
    InventoryTransactionCommand command,
  ) async => _transaction(
    await _source.recordTransaction({
      'p_command_id': command.commandId,
      'p_product_id': command.productId,
      'p_location_id': command.locationId,
      'p_quantity': command.quantity,
      'p_reason': _reasonToDatabase[command.reason],
      'p_notes': command.notes,
      'p_actor_name': _device.actorName,
      'p_device_name': _device.name,
      'p_device_identifier': _device.identifier,
    }),
  );

  @override
  Future<InventoryTransaction> reverseInventoryTransaction(
    InventoryReversalCommand command,
  ) async => _transaction(
    await _source.reverseTransaction({
      'p_command_id': command.commandId,
      'p_original_transaction_id': command.originalTransactionId,
      'p_notes': command.notes,
      'p_actor_name': _device.actorName,
      'p_device_name': _device.name,
      'p_device_identifier': _device.identifier,
    }),
  );

  @override
  Future<InventoryTransaction> addTransaction({
    required String productId,
    required int quantity,
    required InventoryReason reason,
    required String locationId,
    String? notes,
  }) => recordTransaction(
    InventoryTransactionCommand(
      commandId: const Uuid().v4(),
      productId: productId,
      locationId: locationId,
      quantity: quantity,
      reason: reason,
      notes: notes,
    ),
  );

  @override
  Future<InventoryTransaction> reverseTransaction(
    InventoryTransaction original, {
    required String notes,
  }) => reverseInventoryTransaction(
    InventoryReversalCommand(
      commandId: const Uuid().v4(),
      originalTransactionId: original.id,
      notes: notes,
    ),
  );

  @override
  Future<Warehouse> saveWarehouse({
    String? id,
    required String code,
    required String name,
  }) async {
    final row = await _source.saveWarehouse(
      _auditValues(code: code, name: name, isNew: id == null),
      id: id,
    );
    return _warehouse({...row, 'inventory_locations': <dynamic>[]});
  }

  @override
  Future<InventoryLocation> saveLocation({
    String? id,
    required String warehouseId,
    required String code,
    required String name,
  }) async => _location(
    await _source.saveLocation({
      ..._auditValues(code: code, name: name, isNew: id == null),
      'warehouse_id': warehouseId,
    }, id: id),
  );

  Map<String, dynamic> _auditValues({
    required String code,
    required String name,
    required bool isNew,
  }) => {
    'code': code.trim().toUpperCase(),
    'name': name.trim(),
    'updated_by': _device.actorName,
    'updated_device_name': _device.name,
    'updated_device_identifier': _device.identifier,
    if (isNew) 'created_by': _device.actorName,
    if (isNew) 'created_device_name': _device.name,
    if (isNew) 'created_device_identifier': _device.identifier,
  };

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
        warehouseId: row['warehouse_id'] as String,
        locationId: row['location_id'] as String,
        commandId: row['command_id'] as String,
        warehouseName:
            (row['warehouses'] as Map<String, dynamic>?)?['name'] as String?,
        locationName:
            (row['inventory_locations'] as Map<String, dynamic>?)?['name']
                as String?,
        notes: row['notes'] as String?,
        reversalOfTransactionId: row['reversal_of_transaction_id'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  Warehouse _warehouse(Map<String, dynamic> row) => Warehouse(
    id: row['id'] as String,
    code: row['code'] as String,
    name: row['name'] as String,
    isDefault: row['is_default'] as bool,
    isActive: row['is_active'] as bool,
    locations:
        ((row['inventory_locations'] as List<dynamic>?) ?? const [])
            .map((value) => _location(value as Map<String, dynamic>))
            .toList()
          ..sort((a, b) {
            if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
            return a.name.compareTo(b.name);
          }),
  );

  InventoryLocation _location(Map<String, dynamic> row) => InventoryLocation(
    id: row['id'] as String,
    warehouseId: row['warehouse_id'] as String,
    code: row['code'] as String,
    name: row['name'] as String,
    isDefault: row['is_default'] as bool? ?? false,
    isActive: row['is_active'] as bool? ?? true,
  );
}
