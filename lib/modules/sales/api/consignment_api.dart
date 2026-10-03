import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/sales_consignment.dart';
import '../domain/repositories/consignment_repository.dart';

export '../domain/entities/sales_consignment.dart';

abstract interface class ConsignmentApi {
  Future<List<SalesConsignment>> getConsignments();
  Future<SalesConsignment?> getConsignmentById(String id);
  Future<SalesConsignment> createConsignment({
    required String customerId,
    required String customerName,
    required String currencyCode,
    String? notes,
    String? agentId,
    required List<ConsignmentLineInput> lines,
    required String warehouseId,
    required String locationId,
  });
  Future<SalesConsignment> registerReturn({
    required String consignmentId,
    required String productId,
    required int quantity,
  });
}

final consignmentApiProvider = Provider<ConsignmentApi>(
  (ref) => throw StateError('ConsignmentApi must be overridden.'),
);

final consignmentsProvider = FutureProvider<List<SalesConsignment>>(
  (ref) => ref.watch(consignmentApiProvider).getConsignments(),
);
