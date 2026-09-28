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
    return query.order('created_at', ascending: false).limit(500);
  }
}
