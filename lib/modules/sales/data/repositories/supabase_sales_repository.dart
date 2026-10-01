import '../../../../core/identity/identity_context.dart';
import '../../api/sales_api.dart';
import '../../domain/repositories/sales_repository.dart';
import '../data_sources/supabase_sales_data_source.dart';
import '../models/sales_agent_model.dart';

class SupabaseSalesRepository implements SalesRepository {
  const SupabaseSalesRepository(this._source);

  final SupabaseSalesDataSource _source;

  @override
  Future<List<SalesAgentDto>> getAgents(SalesAgentQuery query) async =>
      (await _source.getAgents(activeOnly: query.activeOnly))
          .map(SalesAgentModel.fromJson)
          .map((model) => model.toApi())
          .toList();

  @override
  Future<SalesAgentDto> createAgent(CreateSalesAgentCommand command) async =>
      SalesAgentModel.fromJson(
        await _source.execute('create_sales_agent', {
          'p_command_id': command.commandId,
          'p_name': command.name.trim(),
          'p_phone': command.phone.trim(),
          ..._identity(command.identity),
        }),
      ).toApi();

  @override
  Future<SalesAgentDto> updateAgent(UpdateSalesAgentCommand command) async =>
      SalesAgentModel.fromJson(
        await _source.execute('update_sales_agent', {
          'p_agent_id': command.id,
          'p_name': command.name.trim(),
          'p_phone': command.phone.trim(),
          'p_expected_version': command.expectedVersion,
          ..._identity(command.identity),
        }),
      ).toApi();

  @override
  Future<SalesAgentDto> activateAgent(
    ActivateSalesAgentCommand command,
  ) async => SalesAgentModel.fromJson(
    await _source.execute('activate_sales_agent', {
      'p_agent_id': command.id,
      'p_expected_version': command.expectedVersion,
      ..._identity(command.identity),
    }),
  ).toApi();

  @override
  Future<SalesAgentDto> deactivateAgent(
    DeactivateSalesAgentCommand command,
  ) async => SalesAgentModel.fromJson(
    await _source.execute('deactivate_sales_agent', {
      'p_agent_id': command.id,
      'p_expected_version': command.expectedVersion,
      ..._identity(command.identity),
    }),
  ).toApi();

  Map<String, dynamic> _identity(IdentityContext identity) => {
    'p_actor_name': identity.actorName,
    'p_device_name': identity.deviceName,
    'p_device_identifier': identity.deviceIdentifier,
  };
}
