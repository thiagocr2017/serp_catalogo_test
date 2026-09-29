import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseInventoryDataSource {
  const SupabaseInventoryDataSource(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> transactions({String? productId}) async {
    var query = _client
        .from('inventory_transactions')
        .select(
          '*, products(sku), warehouses(name), inventory_locations(name)',
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
      .select('*, products(sku), warehouses(name), inventory_locations(name)')
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
          '*, products(sku), warehouses(name), inventory_locations(name)',
        );
    if (productId != null) query = query.eq('product_id', productId);
    return query.order('updated_at', ascending: false);
  }

  Future<Map<String, dynamic>> saveWarehouse(
    Map<String, dynamic> values, {
    String? id,
  }) async {
    if (id == null) {
      return _client.from('warehouses').insert(values).select().single();
    }
    return _client
        .from('warehouses')
        .update(values)
        .eq('id', id)
        .select()
        .single();
  }

  Future<Map<String, dynamic>> saveLocation(
    Map<String, dynamic> values, {
    String? id,
  }) async {
    if (id == null) {
      return _client
          .from('inventory_locations')
          .insert(values)
          .select()
          .single();
    }
    return _client
        .from('inventory_locations')
        .update(values)
        .eq('id', id)
        .select()
        .single();
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
