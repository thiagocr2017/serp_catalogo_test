import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/identity/identity_context.dart';
import 'package:serp/core/identity/identity_context_provider.dart';
import 'package:serp/modules/sales/api/sales_api.dart';
import 'package:serp/modules/sales/presentation/pages/agent_page.dart';

void main() {
  testWidgets('agente sin nombre exige correccion antes de guardar', (
    tester,
  ) async {
    final api = _RecordingSalesApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesApiProvider.overrideWithValue(api),
          identityContextProvider.overrideWithValue(
            const IdentityContext(
              actorName: 'test',
              deviceName: 'device',
              deviceIdentifier: 'device-1',
            ),
          ),
        ],
        child: const MaterialApp(home: AgentPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo agente'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Escriba el nombre del agente.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(api.createdAgents, 0);

    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Thiago');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdAgents, 1);
  });
}

class _RecordingSalesApi implements SalesApi {
  int createdAgents = 0;

  @override
  Future<List<SalesAgentDto>> getAgents(SalesAgentQuery query) async =>
      const [];

  @override
  Future<SalesAgentDto> createAgent(CreateSalesAgentCommand command) async {
    createdAgents++;
    return SalesAgentDto(
      id: command.commandId,
      name: command.name,
      phone: command.phone,
      isActive: true,
      version: 1,
    );
  }

  @override
  Future<SalesAgentDto> updateAgent(UpdateSalesAgentCommand command) async =>
      SalesAgentDto(
        id: command.id,
        name: command.name,
        phone: command.phone,
        isActive: true,
        version: command.expectedVersion + 1,
      );

  @override
  Future<SalesAgentDto> activateAgent(
    ActivateSalesAgentCommand command,
  ) async => SalesAgentDto(
    id: command.id,
    name: 'Activo',
    phone: '',
    isActive: true,
    version: command.expectedVersion + 1,
  );

  @override
  Future<SalesAgentDto> deactivateAgent(
    DeactivateSalesAgentCommand command,
  ) async => SalesAgentDto(
    id: command.id,
    name: 'Inactivo',
    phone: '',
    isActive: false,
    version: command.expectedVersion + 1,
  );
}
