import '../../api/sales_api.dart';

/// Coordina comandos públicos de agentes. La pantalla se migrará en 1B.3.
class SalesAgentCommandController {
  const SalesAgentCommandController(this._api);

  final SalesCommandApi _api;

  Future<SalesAgent> create(CreateSalesAgentCommand command) =>
      _api.createAgentCommand(command);

  Future<SalesAgent> update(UpdateSalesAgentCommand command) =>
      _api.updateAgentCommand(command);

  Future<SalesAgent> activate(ActivateSalesAgentCommand command) =>
      _api.activateAgentCommand(command);

  Future<void> deactivate(DeactivateSalesAgentCommand command) =>
      _api.deactivateAgentCommand(command);
}
