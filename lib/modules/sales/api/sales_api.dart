import 'package:flutter_riverpod/flutter_riverpod.dart';

class SalesAgent {
  const SalesAgent({required this.id, required this.name, required this.phone});

  final String id;
  final String name;
  final String phone;
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
