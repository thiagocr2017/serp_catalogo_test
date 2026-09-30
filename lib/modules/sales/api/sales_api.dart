import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sales_commands.dart';

export 'sales_commands.dart';

class SalesAgent {
  const SalesAgent({required this.id, required this.name, required this.phone});

  final String id;
  final String name;
  final String phone;
}

/// Contrato de comandos que sustituirá gradualmente la API heredada en 1B.3.
abstract interface class SalesCommandApi {
  Future<SalesAgent> createAgentCommand(CreateSalesAgentCommand command);
  Future<SalesAgent> updateAgentCommand(UpdateSalesAgentCommand command);
  Future<SalesAgent> activateAgentCommand(ActivateSalesAgentCommand command);
  Future<void> deactivateAgentCommand(DeactivateSalesAgentCommand command);
}

abstract interface class SalesApi {
  Future<List<SalesAgent>> getAgents();

  Future<SalesAgent> createAgent({required String name, required String phone});

  Future<SalesAgent> updateAgent({
    required String id,
    required String name,
    required String phone,
  });

  Future<void> deactivateAgent(String id);
}

final salesApiProvider = Provider<SalesApi>(
  (ref) => throw StateError('SalesApi must be overridden.'),
);

final salesAgentsProvider = FutureProvider<List<SalesAgent>>(
  (ref) => ref.watch(salesApiProvider).getAgents(),
);
