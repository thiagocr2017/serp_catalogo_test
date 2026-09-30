import '../../api/sales_api.dart';

/// Coordina comandos públicos de agentes. La pantalla se migrará en 1B.3.
class SalesAgentCommandController {
  const SalesAgentCommandController(this._api);

  final SalesApi _api;

  Future<SalesAgentDto> create(CreateSalesAgentCommand command) =>
      _api.createAgent(command);

  Future<SalesAgentDto> update(UpdateSalesAgentCommand command) =>
      _api.updateAgent(command);

  Future<SalesAgentDto> activate(ActivateSalesAgentCommand command) =>
      _api.activateAgent(command);

  Future<SalesAgentDto> deactivate(DeactivateSalesAgentCommand command) =>
      _api.deactivateAgent(command);
}
