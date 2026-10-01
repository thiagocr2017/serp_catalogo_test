import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSalesDataSource {
  const SupabaseSalesDataSource(this.client);

  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> getAgents({
    required bool activeOnly,
  }) async {
    final table = client.from('sales_agents');
    if (activeOnly) {
      return await table.select().eq('is_active', true).order('name');
    }
    return await table.select().order('name');
  }

  Future<Map<String, dynamic>> execute(
    String function,
    Map<String, dynamic> parameters,
  ) async => Map<String, dynamic>.from(
    await client.rpc<dynamic>(function, params: parameters) as Map,
  );
}
