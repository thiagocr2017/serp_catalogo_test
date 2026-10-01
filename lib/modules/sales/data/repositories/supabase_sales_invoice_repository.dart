import '../../api/sales_invoice_api.dart';
import '../data_sources/supabase_sales_invoice_data_source.dart';

class SupabaseSalesInvoiceRepository
    implements SalesInvoiceRepository, SalesInvoiceApi {
  const SupabaseSalesInvoiceRepository(this._source);

  final SupabaseSalesInvoiceDataSource _source;

  @override
  Future<List<SalesInvoice>> getInvoices() => _source.getInvoices();

  @override
  Future<SalesInvoice?> getInvoiceById(String id) =>
      _source.getInvoiceById(id);

  @override
  Future<SalesInvoice> createInvoice({
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    required List<SalesInvoiceLineInput> lines,
    required String warehouseId,
    required String locationId,
  }) => _source.createInvoice(
    customerName: customerName,
    currencyCode: currencyCode,
    exchangeRate: exchangeRate,
    notes: notes,
    lines: lines,
    warehouseId: warehouseId,
    locationId: locationId,
  );

  @override
  Future<SalesInvoice> cancelInvoice(String id, {required String reason}) =>
      _source.cancelInvoice(id, reason: reason);
}
