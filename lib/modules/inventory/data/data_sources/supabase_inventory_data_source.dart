import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseInventoryDataSource {
  const SupabaseInventoryDataSource(this._client);
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> transactions({String? productId}) async {
    var query = _client
        .from('inventory_transactions')
        .select('*, products(sku)');
    if (productId != null) query = query.eq('product_id', productId);
    return query.order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> insertTransaction(Map<String, dynamic> values) =>
      _client.from('inventory_transactions').insert(values).select().single();

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
