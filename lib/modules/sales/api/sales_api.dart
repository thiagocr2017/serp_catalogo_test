import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sales_commands.dart';
import 'sales_dtos.dart';

export 'sales_commands.dart';
export 'sales_dtos.dart';

abstract interface class SalesApi {
  Future<List<SalesAgentDto>> getAgents(SalesAgentQuery query);

  Future<SalesAgentDto> createAgent(CreateSalesAgentCommand command);
  Future<SalesAgentDto> updateAgent(UpdateSalesAgentCommand command);
  Future<SalesAgentDto> activateAgent(ActivateSalesAgentCommand command);
  Future<SalesAgentDto> deactivateAgent(DeactivateSalesAgentCommand command);
}

final salesApiProvider = Provider<SalesApi>(
  (ref) => throw StateError('SalesApi must be overridden.'),
);

final salesAgentsProvider = FutureProvider<List<SalesAgentDto>>(
  (ref) => ref.watch(salesApiProvider).getAgents(const SalesAgentQuery()),
);
