import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sales_document_dtos.dart';

export 'sales_document_dtos.dart';

abstract interface class ConsignmentApi {
  Future<List<SalesConsignmentDto>> getConsignments();
  Future<SalesConsignmentDto?> getConsignmentById(String id);
  Future<SalesConsignmentDto> createConsignment({
    required String customerId,
    required String customerName,
    required String currencyCode,
    String? notes,
    String? agentId,
    required List<ConsignmentLineInput> lines,
    required String warehouseId,
    required String locationId,
  });
  Future<SalesConsignmentDto> registerReturn({
    required String consignmentId,
    required String productId,
    required int quantity,
  });
}

final consignmentApiProvider = Provider<ConsignmentApi>(
  (ref) => throw StateError('ConsignmentApi must be overridden.'),
);

final consignmentsProvider = FutureProvider<List<SalesConsignmentDto>>(
  (ref) => ref.watch(consignmentApiProvider).getConsignments(),
);

final consignmentByIdProvider =
    FutureProvider.family<SalesConsignmentDto?, String>(
      (ref, id) => ref.watch(consignmentApiProvider).getConsignmentById(id),
    );
