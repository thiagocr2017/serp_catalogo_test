import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sales_document_dtos.dart';

export 'sales_document_dtos.dart';

abstract interface class ReturnApi {
  Future<List<SalesReturnDto>> getReturns();
  Future<SalesReturnDto?> getReturnById(String id);
  Future<SalesReturnDto> createReturn({
    required String invoiceId,
    required String customerId,
    required String customerName,
    required String reason,
    required List<ReturnLineInput> lines,
  });
}

final returnApiProvider = Provider<ReturnApi>(
  (ref) => throw StateError('ReturnApi must be overridden.'),
);

final returnsProvider = FutureProvider<List<SalesReturnDto>>(
  (ref) => ref.watch(returnApiProvider).getReturns(),
);

final returnByIdProvider = FutureProvider.family<SalesReturnDto?, String>(
  (ref, id) => ref.watch(returnApiProvider).getReturnById(id),
);
