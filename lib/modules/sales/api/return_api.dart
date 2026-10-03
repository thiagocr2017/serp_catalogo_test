import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/sales_return.dart';
import '../domain/repositories/return_repository.dart';

export '../domain/entities/sales_return.dart';

abstract interface class ReturnApi {
  Future<List<SalesReturn>> getReturns();
  Future<SalesReturn?> getReturnById(String id);
  Future<SalesReturn> createReturn({
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

final returnsProvider = FutureProvider<List<SalesReturn>>(
  (ref) => ref.watch(returnApiProvider).getReturns(),
);
