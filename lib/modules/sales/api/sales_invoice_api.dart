import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/sales_invoice.dart';
import '../domain/repositories/sales_invoice_repository.dart';

export '../domain/entities/sales_invoice.dart';

abstract interface class SalesInvoiceApi {
  Future<List<SalesInvoice>> getInvoices();
  Future<SalesInvoice?> getInvoiceById(String id);
  Future<SalesInvoice> createInvoice({
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    required List<SalesInvoiceLineInput> lines,
    required String warehouseId,
    required String locationId,
  });
  Future<SalesInvoice> cancelInvoice(String id, {required String reason});
}

final salesInvoiceApiProvider = Provider<SalesInvoiceApi>(
  (ref) => throw StateError('SalesInvoiceApi must be overridden.'),
);

final salesInvoicesProvider = FutureProvider<List<SalesInvoice>>(
  (ref) => ref.watch(salesInvoiceApiProvider).getInvoices(),
);
