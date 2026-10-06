import '../../domain/entities/sales_invoice.dart';
import '../../domain/repositories/sales_invoice_repository.dart';
import '../data_sources/supabase_sales_invoice_data_source.dart';

class SupabaseSalesInvoiceRepository implements SalesInvoiceRepository {
  const SupabaseSalesInvoiceRepository(this._source);

  final SupabaseSalesInvoiceDataSource _source;

  @override
  Future<List<SalesInvoice>> getInvoices() => _source.getInvoices();

  @override
  Future<SalesInvoice?> getInvoiceById(String id) => _source.getInvoiceById(id);

  @override
  Future<SalesInvoice> createInvoice({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    required List<SalesInvoiceLineInput> lines,
    required String warehouseId,
  }) => _source.createInvoice(
    customerId: customerId,
    customerName: customerName,
    currencyCode: currencyCode,
    exchangeRate: exchangeRate,
    notes: notes,
    lines: lines,
    warehouseId: warehouseId,
  );

  @override
  Future<SalesInvoice> cancelInvoice(String id, {required String reason}) =>
      _source.cancelInvoice(id, reason: reason);
}
