import '../../../../core/device/device_identity.dart';
import '../../api/sales_api.dart';
import '../../domain/repositories/sales_repository.dart';
import '../data_sources/supabase_sales_data_source.dart';
import '../models/sales_agent_model.dart';

class SupabaseSalesRepository implements SalesRepository {
  const SupabaseSalesRepository(this._source, this._device);

  final SupabaseSalesDataSource _source;
  final DeviceIdentity _device;

  @override
  Future<List<SalesAgentDto>> getAgents(SalesAgentQuery query) async =>
      (await _source.getAgents(activeOnly: query.activeOnly))
          .map(SalesAgentModel.fromJson)
          .map((model) => model.toApi())
          .toList();

  @override
  Future<SalesAgentDto> createLegacyAgent({
    required String name,
    required String phone,
  }) async => SalesAgentModel.fromJson(
    await _source.createAgent({
      'name': name.trim(),
      'phone': phone.trim(),
      'created_by': _device.actorName,
      'created_device_name': _device.name,
      'created_device_identifier': _device.identifier,
    }),
  ).toApi();

  @override
  Future<SalesAgentDto> updateLegacyAgent({
    required String id,
    required String name,
    required String phone,
  }) async => SalesAgentModel.fromJson(
    await _source.updateAgent(id, {
      'name': name.trim(),
      'phone': phone.trim(),
      ..._updateMetadata,
    }),
  ).toApi();

  @override
  Future<void> deactivateLegacyAgent(String id) =>
      _source.deactivateAgent(id, {'is_active': false, ..._updateMetadata});

  @override
  Future<SalesAgentDto> createAgent(CreateSalesAgentCommand command) =>
      throw UnsupportedError('Los comandos de agentes se habilitarán en 1B.3.');

  @override
  Future<SalesAgentDto> updateAgent(UpdateSalesAgentCommand command) =>
      throw UnsupportedError('Los comandos de agentes se habilitarán en 1B.3.');

  @override
  Future<SalesAgentDto> activateAgent(ActivateSalesAgentCommand command) =>
      throw UnsupportedError('Los comandos de agentes se habilitarán en 1B.3.');

  @override
  Future<SalesAgentDto> deactivateAgent(DeactivateSalesAgentCommand command) =>
      throw UnsupportedError('Los comandos de agentes se habilitarán en 1B.3.');

  Map<String, dynamic> get _updateMetadata => {
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'updated_by': _device.actorName,
    'updated_device_name': _device.name,
    'updated_device_identifier': _device.identifier,
  };
}
