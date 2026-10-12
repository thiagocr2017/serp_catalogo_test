import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/inventory_document.dart';

class SupabaseInventoryDataSource {
  const SupabaseInventoryDataSource(this._client);
  final SupabaseClient _client;
  static const _labelQueryBatchSize = 100;

  Future<List<Map<String, dynamic>>> transactions({String? productId}) async {
    var query = _client
        .from('inventory_transactions')
        .select(
          '*, products(sku), warehouses(name), '
          'inventory_locations!inventory_transactions_location_id_fkey(name), '
          'inventory_documents(document_number)',
        );
    if (productId != null) query = query.eq('product_id', productId);
    return query.order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> recordTransaction(
    Map<String, dynamic> parameters,
  ) async {
    final created = await _client.rpc<Map<String, dynamic>>(
      'record_inventory_transaction',
      params: parameters,
    );
    return transaction(created['id'] as String);
  }

  Future<Map<String, dynamic>> reverseTransaction(
    Map<String, dynamic> parameters,
  ) async {
    final created = await _client.rpc<Map<String, dynamic>>(
      'reverse_inventory_transaction',
      params: parameters,
    );
    return transaction(created['id'] as String);
  }

  Future<Map<String, dynamic>> transaction(String id) => _client
      .from('inventory_transactions')
      .select(
        '*, products(sku), warehouses(name), '
        'inventory_locations!inventory_transactions_location_id_fkey(name), '
        'inventory_documents(document_number)',
      )
      .eq('id', id)
      .single();

  Future<List<Map<String, dynamic>>> warehouses({
    bool activeOnly = true,
  }) async {
    var query = _client.from('warehouses').select('*, inventory_locations(*)');
    if (activeOnly) query = query.eq('is_active', true);
    return query.order('is_default', ascending: false).order('name');
  }

  Future<List<Map<String, dynamic>>> balances({String? productId}) async {
    var query = _client
        .from('inventory_balances')
        .select(
          '*, products(sku), warehouses(name), '
          'inventory_locations!inventory_balances_location_id_fkey(name)',
        );
    if (productId != null) query = query.eq('product_id', productId);
    return query.order('updated_at', ascending: false);
  }

  static const _documentSelect = '''
    *,
    origin_warehouse:warehouses!inventory_documents_origin_warehouse_id_fkey(name),
    origin_location:inventory_locations!inventory_documents_origin_location_id_fkey(name),
    destination_warehouse:warehouses!inventory_documents_destination_warehouse_id_fkey(name),
    destination_location:inventory_locations!inventory_documents_destination_location_id_fkey(name),
    inventory_document_lines(*, products(sku, name))
  ''';

  Future<List<Map<String, dynamic>>> documents() => _client
      .from('inventory_documents')
      .select(_documentSelect)
      .order('created_at', ascending: false);

  Future<Map<String, dynamic>?> document(String id) => _client
      .from('inventory_documents')
      .select(_documentSelect)
      .eq('id', id)
      .maybeSingle();

  InventoryDocument _document(Map<String, dynamic> row) => InventoryDocument(
    id: row['id'] as String,
    number: row['document_number'] as String,
    type: InventoryDocumentType.values.byName(
      (row['document_type'] as String).toLowerCase(),
    ),
    status: row['status'] as String,
    lines: (row['inventory_document_lines'] as List<dynamic>).map((line) {
      final l = line as Map<String, dynamic>;
      return InventoryDocumentLine(
        id: l['id'] as String,
        productId: l['product_id'] as String,
        quantity: l['quantity'] as int,
        productSku: l['product_sku'] as String?,
        productName: l['product_name'] as String?,
        notes: l['notes'] as String?,
      );
    }).toList(),
    originWarehouseName: row['origin_warehouse']?['name'] as String?,
    originLocationName: row['origin_location']?['name'] as String?,
    destinationWarehouseName: row['destination_warehouse']?['name'] as String?,
    destinationLocationName: row['destination_location']?['name'] as String?,
    externalReference: row['external_reference'] as String?,
    notes: row['notes'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: row['updated_at'] == null
        ? null
        : DateTime.parse(row['updated_at'] as String),
  );

  Future<Map<String, dynamic>> createAndConfirmDocument(
    Map<String, dynamic> parameters,
  ) async {
    final created = await _client.rpc<Map<String, dynamic>>(
      'create_and_confirm_inventory_document',
      params: parameters,
    );
    return (await document(created['id'] as String))!;
  }

  Future<Map<String, dynamic>> saveWarehouse(
    Map<String, dynamic> values, {
    String? id,
  }) async {
    if (id == null) {
      return _client.rpc<Map<String, dynamic>>(
        'create_warehouse',
        params: {
          'p_code': values['code'],
          'p_name': values['name'],
          'p_is_default': values['is_default'] ?? false,
          'p_actor_name': values['created_by'],
          'p_device_name': values['created_device_name'],
          'p_device_identifier': values['created_device_identifier'],
        },
      );
    }
    return _client.rpc<Map<String, dynamic>>(
      'update_warehouse',
      params: {
        'p_warehouse_id': id,
        'p_code': values['code'],
        'p_name': values['name'],
        'p_is_default': values['is_default'] ?? false,
        'p_is_active': values['is_active'] ?? true,
        'p_actor_name': values['updated_by'],
        'p_device_name': values['updated_device_name'],
        'p_device_identifier': values['updated_device_identifier'],
      },
    );
  }

  Future<Map<String, dynamic>> saveLocation(
    Map<String, dynamic> values, {
    String? id,
  }) async {
    if (id == null) {
      return _client.rpc<Map<String, dynamic>>(
        'create_inventory_location',
        params: {
          'p_warehouse_id': values['warehouse_id'],
          'p_code': values['code'],
          'p_name': values['name'],
          'p_is_default': values['is_default'] ?? false,
          'p_actor_name': values['created_by'],
          'p_device_name': values['created_device_name'],
          'p_device_identifier': values['created_device_identifier'],
        },
      );
    }
    return _client.rpc<Map<String, dynamic>>(
      'update_inventory_location',
      params: {
        'p_location_id': id,
        'p_code': values['code'],
        'p_name': values['name'],
        'p_is_default': values['is_default'] ?? false,
        'p_is_active': values['is_active'] ?? true,
        'p_actor_name': values['updated_by'],
        'p_device_name': values['updated_device_name'],
        'p_device_identifier': values['updated_device_identifier'],
      },
    );
  }

  Future<List<Map<String, dynamic>>> audit({
    String? tableName,
    String? recordId,
  }) async {
    var query = _client.from('audit_logs').select();
    if (tableName != null) query = query.eq('table_name', tableName);
    if (recordId != null) query = query.eq('record_id', recordId);
    return query.order('created_at', ascending: false).limit(2000);
  }

  Future<Map<String, String>> productLabels(Iterable<String> ids) async {
    final values = ids.toSet().toList();
    if (values.isEmpty) return const {};
    final batches = _splitIds(values);
    final resultBatches = await Future.wait(
      batches.map(
        (batch) => _client
            .from('products')
            .select('id, sku, name')
            .inFilter('id', batch),
      ),
    );
    return {
      for (final row in resultBatches.expand((rows) => rows))
        row['id'] as String:
            '${row['sku'] as String} · ${row['name'] as String}',
    };
  }

  Future<Map<String, String>> categoryLabels(Iterable<String> ids) async {
    final values = ids.toSet().toList();
    if (values.isEmpty) return const {};
    final batches = _splitIds(values);
    final resultBatches = await Future.wait(
      batches.map(
        (batch) =>
            _client.from('categories').select('id, name').inFilter('id', batch),
      ),
    );
    return {
      for (final row in resultBatches.expand((rows) => rows))
        row['id'] as String: row['name'] as String,
    };
  }

  List<List<String>> _splitIds(List<String> ids) => [
    for (var start = 0; start < ids.length; start += _labelQueryBatchSize)
      ids.sublist(
        start,
        start + _labelQueryBatchSize < ids.length
            ? start + _labelQueryBatchSize
            : ids.length,
      ),
  ];

  // Advanced inventory

  Future<Map<String, dynamic>> reserveStock({
    required String productId,
    required String locationId,
    required String orderId,
    required int quantity,
    required String actorName,
    required String deviceName,
    required String deviceIdentifier,
  }) => _client.rpc<Map<String, dynamic>>(
    'reserve_inventory',
    params: {
      'p_command_id': const Uuid().v4(),
      'p_product_id': productId,
      'p_location_id': locationId,
      'p_order_id': orderId,
      'p_quantity': quantity,
      'p_actor_name': actorName,
      'p_device_name': deviceName,
      'p_device_identifier': deviceIdentifier,
    },
  );

  Future<void> releaseReservation(
    String reservationId, {
    required String actorName,
    required String deviceName,
    required String deviceIdentifier,
  }) => _client.rpc<void>(
    'release_reservation',
    params: {
      'p_reservation_id': reservationId,
      'p_actor_name': actorName,
      'p_device_name': deviceName,
      'p_device_identifier': deviceIdentifier,
    },
  );

  Future<void> consumeReservation(
    String reservationId, {
    required String actorName,
    required String deviceName,
    required String deviceIdentifier,
  }) => _client.rpc<void>(
    'consume_reservation',
    params: {
      'p_reservation_id': reservationId,
      'p_actor_name': actorName,
      'p_device_name': deviceName,
      'p_device_identifier': deviceIdentifier,
    },
  );

  Future<List<Map<String, dynamic>>> getReservations() => _client
      .from('inventory_reservations')
      .select()
      .order('created_at', ascending: false);

  Future<Map<String, dynamic>> createCount({
    required String warehouseId,
    required String actorName,
    required String deviceName,
    required String deviceIdentifier,
  }) => _client.rpc<Map<String, dynamic>>(
    'create_inventory_count',
    params: {
      'p_warehouse_id': warehouseId,
      'p_actor_name': actorName,
      'p_device_name': deviceName,
      'p_device_identifier': deviceIdentifier,
    },
  );

  Future<void> confirmCount(
    String countId, {
    required String actorName,
    required String deviceName,
    required String deviceIdentifier,
  }) => _client.rpc<void>(
    'confirm_count_and_adjust',
    params: {
      'p_count_id': countId,
      'p_actor_name': actorName,
      'p_device_name': deviceName,
      'p_device_identifier': deviceIdentifier,
    },
  );

  Future<void> dispatchTransfer(
    String documentId, {
    required String actorName,
    required String deviceName,
    required String deviceIdentifier,
  }) => _client.rpc<void>(
    'dispatch_transfer',
    params: {
      'p_document_id': documentId,
      'p_actor_name': actorName,
      'p_device_name': deviceName,
      'p_device_identifier': deviceIdentifier,
    },
  );

  Future<void> markTransferInTransit(
    String documentId, {
    required String actorName,
    required String deviceName,
    required String deviceIdentifier,
  }) => _client.rpc<void>(
    'mark_transfer_in_transit',
    params: {
      'p_document_id': documentId,
      'p_actor_name': actorName,
      'p_device_name': deviceName,
      'p_device_identifier': deviceIdentifier,
    },
  );

  Future<void> receiveTransfer(
    String documentId, {
    required String actorName,
    required String deviceName,
    required String deviceIdentifier,
  }) => _client.rpc<void>(
    'receive_transfer',
    params: {
      'p_document_id': documentId,
      'p_actor_name': actorName,
      'p_device_name': deviceName,
      'p_device_identifier': deviceIdentifier,
    },
  );

  Future<InventoryDocument> confirmDocument(
    String documentId, {
    required String actorName,
    required String deviceName,
    required String deviceIdentifier,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'confirm_inventory_document',
      params: {
        'p_document_id': documentId,
        'p_actor_name': actorName,
        'p_device_name': deviceName,
        'p_device_identifier': deviceIdentifier,
      },
    );
    return _document(row);
  }

  Future<void> dispatchDocument(
    String documentId, {
    required String actorName,
    required String deviceName,
    required String deviceIdentifier,
  }) => _client.rpc<void>(
    'dispatch_transfer',
    params: {
      'p_document_id': documentId,
      'p_actor_name': actorName,
      'p_device_name': deviceName,
      'p_device_identifier': deviceIdentifier,
    },
  );
}
