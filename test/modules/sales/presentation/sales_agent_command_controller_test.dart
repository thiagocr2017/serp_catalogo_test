import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/identity/identity_context.dart';
import 'package:serp/modules/sales/api/sales_api.dart';
import 'package:serp/modules/sales/presentation/controllers/sales_agent_command_controller.dart';

class _FakeSalesCommandApi implements SalesCommandApi {
  CreateSalesAgentCommand? createdCommand;

  @override
  Future<SalesAgent> activateAgentCommand(
    ActivateSalesAgentCommand command,
  ) async => const SalesAgent(id: 'agent-1', name: 'Ana', phone: '');

  @override
  Future<SalesAgent> createAgentCommand(CreateSalesAgentCommand command) async {
    createdCommand = command;
    return SalesAgent(id: 'agent-1', name: command.name, phone: command.phone);
  }

  @override
  Future<void> deactivateAgentCommand(
    DeactivateSalesAgentCommand command,
  ) async {}

  @override
  Future<SalesAgent> updateAgentCommand(
    UpdateSalesAgentCommand command,
  ) async =>
      SalesAgent(id: command.id, name: command.name, phone: command.phone);
}

void main() {
  test(
    'controller forwards the required idempotency key when creating an agent',
    () async {
      final api = _FakeSalesCommandApi();
      final controller = SalesAgentCommandController(api);
      const command = CreateSalesAgentCommand(
        commandId: 'agent-command-001',
        name: 'Ana',
        phone: '+50600000000',
        identity: IdentityContext(
          actorName: 'Equipo local',
          deviceName: 'Mac',
          deviceIdentifier: 'device-001',
        ),
      );

      final agent = await controller.create(command);

      expect(api.createdCommand, same(command));
      expect(agent.id, 'agent-1');
    },
  );
}
