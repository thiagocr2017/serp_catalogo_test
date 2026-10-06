import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sales_document_dtos.dart';

export 'sales_document_dtos.dart';

abstract interface class SalesInvoiceApi {
  Future<List<SalesInvoiceDto>> getInvoices();
  Future<SalesInvoiceDto?> getInvoiceById(String id);
  Future<SalesInvoiceDto> createInvoice({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    required List<SalesInvoiceLineInput> lines,
    required String warehouseId,
  });
  Future<SalesInvoiceDto> cancelInvoice(String id, {required String reason});
}

final salesInvoiceApiProvider = Provider<SalesInvoiceApi>(
  (ref) => throw StateError('SalesInvoiceApi must be overridden.'),
);

final salesInvoicesProvider = FutureProvider<List<SalesInvoiceDto>>(
  (ref) => ref.watch(salesInvoiceApiProvider).getInvoices(),
);

final salesInvoiceByIdProvider = FutureProvider.family<SalesInvoiceDto?, String>(
  (ref, id) => ref.watch(salesInvoiceApiProvider).getInvoiceById(id),
);
