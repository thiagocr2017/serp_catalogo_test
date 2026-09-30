import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/identity/identity_context.dart';
import 'package:serp/modules/sales/api/sales_api.dart';
import 'package:serp/modules/sales/presentation/controllers/sales_agent_command_controller.dart';

class _FakeSalesApi implements SalesApi {
  CreateSalesAgentCommand? createdCommand;

  @override
  Future<SalesAgentDto> activateAgent(
    ActivateSalesAgentCommand command,
  ) async => const SalesAgentDto(
    id: 'agent-1',
    name: 'Ana',
    phone: '',
    isActive: true,
    version: 3,
  );

  @override
  Future<SalesAgentDto> createAgent(CreateSalesAgentCommand command) async {
    createdCommand = command;
    return SalesAgentDto(
      id: 'agent-1',
      name: command.name,
      phone: command.phone,
      isActive: true,
      version: 2,
    );
  }

  @override
  Future<SalesAgentDto> deactivateAgent(
    DeactivateSalesAgentCommand command,
  ) async => const SalesAgentDto(
    id: 'agent-1',
    name: 'Ana',
    phone: '',
    isActive: false,
    version: 4,
  );

  @override
  Future<SalesAgentDto> updateAgent(UpdateSalesAgentCommand command) async =>
      SalesAgentDto(
        id: command.id,
        name: command.name,
        phone: command.phone,
        isActive: true,
        version: 3,
      );

  @override
  Future<List<SalesAgentDto>> getAgents() async => const [];

  @override
  Future<SalesAgentDto> createLegacyAgent({
    required String name,
    required String phone,
  }) => throw UnimplementedError();

  @override
  Future<SalesAgentDto> updateLegacyAgent({
    required String id,
    required String name,
    required String phone,
  }) => throw UnimplementedError();

  @override
  Future<void> deactivateLegacyAgent(String id) => throw UnimplementedError();
}

void main() {
  test(
    'controller forwards the required idempotency key when creating an agent',
    () async {
      final api = _FakeSalesApi();
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
      expect(agent.isActive, isTrue);
      expect(agent.version, 2);
    },
  );
}
