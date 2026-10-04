import '../../api/sales_invoice_api.dart';
import '../../domain/repositories/sales_invoice_repository.dart' as domain;
import '../data_sources/supabase_sales_invoice_data_source.dart';
import '../mappers/sales_dto_mapper.dart';

class SupabaseSalesInvoiceApi implements SalesInvoiceApi {
  const SupabaseSalesInvoiceApi(this._source);

  final SupabaseSalesInvoiceDataSource _source;

  @override
  Future<List<SalesInvoiceDto>> getInvoices() async {
    final invoices = await _source.getInvoices();
    return invoices.map((i) => i.toDto()).toList();
  }

  @override
  Future<SalesInvoiceDto?> getInvoiceById(String id) async {
    final invoice = await _source.getInvoiceById(id);
    return invoice?.toDto();
  }

  @override
  Future<SalesInvoiceDto> createInvoice({
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    required List<SalesInvoiceLineInput> lines,
    required String warehouseId,
    required String locationId,
  }) async {
    final invoice = await _source.createInvoice(
      customerName: customerName,
      currencyCode: currencyCode,
      exchangeRate: exchangeRate,
      notes: notes,
      lines: [
        for (final l in lines)
          domain.SalesInvoiceLineInput(
            productId: l.productId,
            quantity: l.quantity,
            unitPrice: l.unitPrice,
            discountPercent: l.discountPercent,
            productSku: l.productSku,
            productName: l.productName,
          ),
      ],
      warehouseId: warehouseId,
      locationId: locationId,
    );
    return invoice.toDto();
  }

  @override
  Future<SalesInvoiceDto> cancelInvoice(String id, {required String reason}) async {
    final invoice = await _source.cancelInvoice(id, reason: reason);
    return invoice.toDto();
  }
}
