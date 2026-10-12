import 'package:uuid/uuid.dart';

import '../../../../core/device/device_identity.dart';
import '../../api/inventory_api.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/entities/inventory_balance.dart';
import '../../domain/entities/inventory_count.dart';
import '../../domain/entities/inventory_document.dart';
import '../../domain/entities/inventory_reservation.dart';
import '../../domain/entities/inventory_transaction.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../data_sources/supabase_inventory_data_source.dart';

// Implementa SOLO el repositorio de dominio, que trabaja con entidades. El
// contrato publico (`InventoryApi`) vive en `supabase_inventory_api.dart`, que
// envuelve este repositorio y traduce a DTO. Dart no permite que una misma clase
// implemente dos `getTransactions` con distinto tipo de retorno.
class SupabaseInventoryRepository implements InventoryRepository {
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
    InventoryReason.transferOut: 'TRANSFER_OUT',
    InventoryReason.transferIn: 'TRANSFER_IN',
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
          reservedQuantity: row['reserved_quantity'] as int? ?? 0,
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
  Future<List<InventoryDocument>> getDocuments() async =>
      (await _source.documents()).map(_document).toList();

  @override
  Future<InventoryDocument?> getDocument(String id) async {
    final row = await _source.document(id);
    return row == null ? null : _document(row);
  }

  @override
  Future<InventoryDocument> createAndConfirmDocument(
    InventoryDocumentCommand command,
  ) async => _document(
    await _source.createAndConfirmDocument({
      'p_command_id': command.commandId,
      'p_document_type': switch (command.type) {
        InventoryDocumentType.adjustment => 'ADJUSTMENT',
        InventoryDocumentType.transfer => 'TRANSFER',
        _ => throw ArgumentError('Tipo de documento no disponible manualmente'),
      },
      'p_lines': [
        for (final line in command.lines)
          {
            'product_id': line.productId,
            'quantity': line.quantity,
            'notes': line.notes,
          },
      ],
      'p_origin_warehouse_id': command.type == InventoryDocumentType.adjustment
          ? command.destinationWarehouseId
          : command.originWarehouseId,
      'p_origin_location_id': command.originLocationId,
      'p_destination_warehouse_id': command.destinationWarehouseId,
      'p_destination_location_id': command.destinationLocationId,
      'p_external_reference': command.externalReference,
      'p_notes': command.notes,
      'p_draft': command.draft,
      'p_actor_name': _device.actorName,
      'p_device_name': _device.name,
      'p_device_identifier': _device.identifier,
    }),
  );

  Future<InventoryTransaction> _recordTransaction({
    required String commandId,
    required String productId,
    required String locationId,
    required int quantity,
    required InventoryReason reason,
    String? notes,
  }) async => _transaction(
    await _source.recordTransaction({
      'p_command_id': commandId,
      'p_product_id': productId,
      'p_location_id': locationId,
      'p_quantity': quantity,
      'p_reason': _reasonToDatabase[reason],
      'p_notes': notes,
      'p_actor_name': _device.actorName,
      'p_device_name': _device.name,
      'p_device_identifier': _device.identifier,
    }),
  );

  Future<InventoryTransaction> _reverseInventoryTransaction({
    required String commandId,
    required String originalTransactionId,
    required String notes,
  }) async => _transaction(
    await _source.reverseTransaction({
      'p_command_id': commandId,
      'p_original_transaction_id': originalTransactionId,
      'p_notes': notes,
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
  }) => _recordTransaction(
    commandId: const Uuid().v4(),
    productId: productId,
    locationId: locationId,
    quantity: quantity,
    reason: reason,
    notes: notes,
  );

  @override
  Future<InventoryTransaction> reverseTransaction(
    InventoryTransaction original, {
    required String notes,
  }) => _reverseInventoryTransaction(
    commandId: const Uuid().v4(),
    originalTransactionId: original.id,
    notes: notes,
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
    final labels = await Future.wait<Map<String, String>>([
      _source.productLabels(productIds),
      _source.categoryLabels(categoryIds),
    ]);
    final products = labels[0];
    final categories = labels[1];
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
          'REVERSAL' => InventoryReason.reversal,
          'TRANSFER_OUT' => InventoryReason.transferOut,
          _ => InventoryReason.transferIn,
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
        documentId: row['document_id'] as String?,
        documentNumber:
            (row['inventory_documents']
                    as Map<String, dynamic>?)?['document_number']
                as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  InventoryDocument _document(Map<String, dynamic> row) => InventoryDocument(
    id: row['id'] as String,
    number: row['document_number'] as String,
    type: switch (row['document_type'] as String) {
      'OPENING' => InventoryDocumentType.opening,
      'ADJUSTMENT' => InventoryDocumentType.adjustment,
      'TRANSFER' => InventoryDocumentType.transfer,
      'PURCHASE_RECEIPT' => InventoryDocumentType.purchaseReceipt,
      'SALE_DISPATCH' => InventoryDocumentType.saleDispatch,
      'CUSTOMER_RETURN' => InventoryDocumentType.customerReturn,
      'SUPPLIER_RETURN' => InventoryDocumentType.supplierReturn,
      _ => InventoryDocumentType.consignment,
    },
    status: row['status'] as String,
    createdAt: DateTime.parse(row['created_at'] as String),
    originWarehouseName:
        (row['origin_warehouse'] as Map<String, dynamic>?)?['name'] as String?,
    originLocationName:
        (row['origin_location'] as Map<String, dynamic>?)?['name'] as String?,
    destinationWarehouseName:
        (row['destination_warehouse'] as Map<String, dynamic>?)?['name']
            as String?,
    destinationLocationName:
        (row['destination_location'] as Map<String, dynamic>?)?['name']
            as String?,
    externalReference: row['external_reference'] as String?,
    notes: row['notes'] as String?,
    lines: ((row['inventory_document_lines'] as List<dynamic>?) ?? const [])
        .map((value) {
          final line = value as Map<String, dynamic>;
          final product = line['products'] as Map<String, dynamic>?;
          return InventoryDocumentLine(
            id: line['id'] as String,
            productId: line['product_id'] as String,
            quantity: line['quantity'] as int,
            productSku: product?['sku'] as String?,
            productName: product?['name'] as String?,
            notes: line['notes'] as String?,
          );
        })
        .toList(),
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
    stockRole: row['stock_role'] as String? ?? 'SELLABLE',
  );

  // Advanced inventory implementation

  @override
  Future<InventoryReservation> reserveStock({
    required String productId,
    required String locationId,
    required String orderId,
    required int quantity,
  }) async {
    final row = await _source.reserveStock(
      productId: productId,
      locationId: locationId,
      orderId: orderId,
      quantity: quantity,
      actorName: _device.actorName,
      deviceName: _device.name,
      deviceIdentifier: _device.identifier,
    );
    return _reservation(row);
  }

  @override
  Future<void> releaseReservation(String reservationId) =>
      _source.releaseReservation(
        reservationId,
        actorName: _device.actorName,
        deviceName: _device.name,
        deviceIdentifier: _device.identifier,
      );

  @override
  Future<void> consumeReservation(String reservationId) =>
      _source.consumeReservation(
        reservationId,
        actorName: _device.actorName,
        deviceName: _device.name,
        deviceIdentifier: _device.identifier,
      );

  @override
  Future<List<InventoryReservation>> getReservations() async {
    final rows = await _source.getReservations();
    return rows.map(_reservation).toList();
  }

  @override
  Future<InventoryCount> createCount(String warehouseId) async {
    final row = await _source.createCount(
      warehouseId: warehouseId,
      actorName: _device.actorName,
      deviceName: _device.name,
      deviceIdentifier: _device.identifier,
    );
    return _count(row);
  }

  @override
  Future<void> confirmCount(String countId) => _source.confirmCount(
    countId,
    actorName: _device.actorName,
    deviceName: _device.name,
    deviceIdentifier: _device.identifier,
  );

  @override
  Future<void> dispatchTransfer(String documentId) => _source.dispatchTransfer(
    documentId,
    actorName: _device.actorName,
    deviceName: _device.name,
    deviceIdentifier: _device.identifier,
  );

  @override
  Future<void> markTransferInTransit(String documentId) =>
      _source.markTransferInTransit(
        documentId,
        actorName: _device.actorName,
        deviceName: _device.name,
        deviceIdentifier: _device.identifier,
      );

  @override
  Future<void> receiveTransfer(String documentId) => _source.receiveTransfer(
    documentId,
    actorName: _device.actorName,
    deviceName: _device.name,
    deviceIdentifier: _device.identifier,
  );

  @override
  Future<InventoryDocument> confirmDocument(String documentId) =>
      _source.confirmDocument(
        documentId,
        actorName: _device.actorName,
        deviceName: _device.name,
        deviceIdentifier: _device.identifier,
      );

  @override
  Future<void> dispatchDocument(String documentId) => _source.dispatchDocument(
    documentId,
    actorName: _device.actorName,
    deviceName: _device.name,
    deviceIdentifier: _device.identifier,
  );

  InventoryReservation _reservation(Map<String, dynamic> row) =>
      InventoryReservation(
        id: row['id'] as String,
        productId: row['product_id'] as String,
        locationId: row['location_id'] as String,
        orderId: row['order_id'] as String,
        quantity: row['quantity'] as int,
        status: switch (row['status'] as String) {
          'PENDING' => ReservationStatus.pending,
          'RELEASED' => ReservationStatus.released,
          'CONSUMED' => ReservationStatus.consumed,
          _ => ReservationStatus.pending,
        },
        commandId: row['command_id'] as String,
        createdAt: row['created_at'] == null
            ? null
            : DateTime.parse(row['created_at'] as String),
        releasedAt: row['released_at'] == null
            ? null
            : DateTime.parse(row['released_at'] as String),
      );

  InventoryCount _count(Map<String, dynamic> row) => InventoryCount(
    id: row['id'] as String,
    warehouseId: row['warehouse_id'] as String,
    status: switch (row['status'] as String) {
      'DRAFT' => CountStatus.draft,
      'COUNTING' => CountStatus.counting,
      'REVIEW' => CountStatus.review,
      'CONFIRMED' => CountStatus.confirmed,
      'CANCELLED' => CountStatus.cancelled,
      _ => CountStatus.draft,
    },
    createdAt: row['created_at'] == null
        ? null
        : DateTime.parse(row['created_at'] as String),
    confirmedAt: row['confirmed_at'] == null
        ? null
        : DateTime.parse(row['confirmed_at'] as String),
  );
}
