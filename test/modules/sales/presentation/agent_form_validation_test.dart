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

  testWidgets('agente existente carga, actualiza, desactiva y activa', (
    tester,
  ) async {
    final api = _RecordingSalesApi(
      initialAgents: const [
        SalesAgentDto(
          id: 'agent-1',
          name: 'Thiago',
          phone: '+506 1111',
          isActive: true,
          version: 3,
        ),
        SalesAgentDto(
          id: 'agent-2',
          name: 'Laura',
          phone: '+506 2222',
          isActive: false,
          version: 4,
        ),
      ],
    );

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

    await tester.tap(find.byTooltip('Editar agente').first);
    await tester.pumpAndSettle();
    expect(find.text('Editar agente'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Thiago'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Thiago L.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.updatedAgentId, 'agent-1');
    expect(api.updatedAgentName, 'Thiago L.');
    expect(api.updatedExpectedVersion, 3);

    await tester.tap(find.byTooltip('Desactivar agente'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(api.deactivatedAgentId, 'agent-1');
    expect(api.deactivatedExpectedVersion, 3);

    await tester.tap(find.byTooltip('Activar agente'));
    await tester.pumpAndSettle();

    expect(api.activatedAgentId, 'agent-2');
    expect(api.activatedExpectedVersion, 4);
  });
}

class _RecordingSalesApi implements SalesApi {
  _RecordingSalesApi({this.initialAgents = const []});

  final List<SalesAgentDto> initialAgents;
  int createdAgents = 0;
  String? updatedAgentId;
  String? updatedAgentName;
  int? updatedExpectedVersion;
  String? deactivatedAgentId;
  int? deactivatedExpectedVersion;
  String? activatedAgentId;
  int? activatedExpectedVersion;

  @override
  Future<List<SalesAgentDto>> getAgents(SalesAgentQuery query) async =>
      initialAgents;

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
  Future<SalesAgentDto> updateAgent(UpdateSalesAgentCommand command) async {
    updatedAgentId = command.id;
    updatedAgentName = command.name;
    updatedExpectedVersion = command.expectedVersion;
    return SalesAgentDto(
      id: command.id,
      name: command.name,
      phone: command.phone,
      isActive: true,
      version: command.expectedVersion + 1,
    );
  }

  @override
  Future<SalesAgentDto> activateAgent(ActivateSalesAgentCommand command) async {
    activatedAgentId = command.id;
    activatedExpectedVersion = command.expectedVersion;
    return SalesAgentDto(
      id: command.id,
      name: 'Activo',
      phone: '',
      isActive: true,
      version: command.expectedVersion + 1,
    );
  }

  @override
  Future<SalesAgentDto> deactivateAgent(
    DeactivateSalesAgentCommand command,
  ) async {
    deactivatedAgentId = command.id;
    deactivatedExpectedVersion = command.expectedVersion;
    return SalesAgentDto(
      id: command.id,
      name: 'Inactivo',
      phone: '',
      isActive: false,
      version: command.expectedVersion + 1,
    );
  }
}
