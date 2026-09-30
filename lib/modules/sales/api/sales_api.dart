import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sales_commands.dart';
import 'sales_dtos.dart';

export 'sales_commands.dart';
export 'sales_dtos.dart';

/// Puente de tipo para consumidores heredados; se elimina en 1B.3.
typedef SalesAgent = SalesAgentDto;

abstract interface class SalesApi {
  Future<List<SalesAgentDto>> getAgents();

  Future<SalesAgentDto> createAgent(CreateSalesAgentCommand command);
  Future<SalesAgentDto> updateAgent(UpdateSalesAgentCommand command);
  Future<SalesAgentDto> activateAgent(ActivateSalesAgentCommand command);
  Future<SalesAgentDto> deactivateAgent(DeactivateSalesAgentCommand command);

  /// Puente temporal para la pantalla heredada; se elimina al migrarla en 1B.3.
  Future<SalesAgentDto> createLegacyAgent({
    required String name,
    required String phone,
  });

  /// Puente temporal para la pantalla heredada; se elimina al migrarla en 1B.3.
  Future<SalesAgentDto> updateLegacyAgent({
    required String id,
    required String name,
    required String phone,
  });

  /// Puente temporal para la pantalla heredada; se elimina al migrarla en 1B.3.
  Future<void> deactivateLegacyAgent(String id);
}

final salesApiProvider = Provider<SalesApi>(
  (ref) => throw StateError('SalesApi must be overridden.'),
);

final salesAgentsProvider = FutureProvider<List<SalesAgentDto>>(
  (ref) => ref.watch(salesApiProvider).getAgents(),
);
