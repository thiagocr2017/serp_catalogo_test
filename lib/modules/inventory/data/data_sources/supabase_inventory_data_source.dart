import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseInventoryDataSource {
  const SupabaseInventoryDataSource(this._client);
  final SupabaseClient _client;

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
    final rows = await _client
        .from('products')
        .select('id, sku, name')
        .inFilter('id', values);
    return {
      for (final row in rows)
        row['id'] as String:
            '${row['sku'] as String} · ${row['name'] as String}',
    };
  }

  Future<Map<String, String>> categoryLabels(Iterable<String> ids) async {
    final values = ids.toSet().toList();
    if (values.isEmpty) return const {};
    final rows = await _client
        .from('categories')
        .select('id, name')
        .inFilter('id', values);
    return {for (final row in rows) row['id'] as String: row['name'] as String};
  }
}
