import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSalesDataSource {
  const SupabaseSalesDataSource(this.client);

  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> getAgents({
    required bool activeOnly,
  }) async {
    final table = client.from('catalog_agents');
    if (activeOnly) {
      return await table.select().eq('is_active', true).order('name');
    }
    return await table.select().order('name');
  }

  Future<Map<String, dynamic>> createAgent(Map<String, dynamic> values) async =>
      await client.from('catalog_agents').insert(values).select().single();

  Future<Map<String, dynamic>> updateAgent(
    String id,
    Map<String, dynamic> values,
  ) async => await client
      .from('catalog_agents')
      .update(values)
      .eq('id', id)
      .select()
      .single();

  Future<void> deactivateAgent(String id, Map<String, dynamic> values) async {
    await client.from('catalog_agents').update(values).eq('id', id);
    await client
        .from('app_settings')
        .update({'selected_catalog_agent_id': null})
        .eq('id', true)
        .eq('selected_catalog_agent_id', id);
  }
}
