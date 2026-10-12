import '../../api/return_api.dart';
import '../../domain/repositories/return_repository.dart' as domain;
import '../data_sources/supabase_return_data_source.dart';
import '../mappers/sales_dto_mapper.dart';

class SupabaseReturnApi implements ReturnApi {
  const SupabaseReturnApi(this._source);

  final SupabaseReturnDataSource _source;

  @override
  Future<List<SalesReturnDto>> getReturns() async {
    final returns = await _source.getReturns();
    return returns.map((r) => r.toDto()).toList();
  }

  @override
  Future<SalesReturnDto?> getReturnById(String id) async {
    final returnItem = await _source.getReturnById(id);
    return returnItem?.toDto();
  }

  @override
  Future<SalesReturnPreviewDto> previewReturn(String invoiceId) async {
    final row = await _source.previewReturn(invoiceId);
    List<ReturnLocationDto> locations(String key) => [
      for (final value in (row[key] as List<dynamic>? ?? const []))
        ReturnLocationDto(
          id: value['id'] as String,
          warehouseId: value['warehouse_id'] as String,
          code: value['code'] as String,
          name: value['name'] as String,
        ),
    ];
    return SalesReturnPreviewDto(
      invoiceId: row['invoice_id'] as String,
      customerId: row['customer_id'] as String,
      customerName: row['customer_name'] as String,
      currencyCode: (row['currency_code'] as String).trim(),
      totalAmount: (row['total_amount'] as num).toDouble(),
      paidAmount: (row['paid_amount'] as num).toDouble(),
      outstandingAmount: (row['outstanding_amount'] as num).toDouble(),
      availableQuantities: {
        for (final line in row['lines'] as List<dynamic>)
          line['id'] as String: line['available_quantity'] as int,
      },
      returnedQuantities: {
        for (final line in row['lines'] as List<dynamic>)
          line['id'] as String: line['returned_quantity'] as int? ?? 0,
      },
      sellableLocations: locations('sellable_locations'),
      quarantineLocations: locations('quarantine_locations'),
    );
  }

  @override
  Future<SalesReturnDto> confirmReturn(
    ConfirmSalesReturnCommand command,
  ) async => (await _source.confirmReturn(command)).toDto();

  @override
  Future<SalesReturnDto> createReturn({
    required String invoiceId,
    required String customerId,
    required String customerName,
    required String reason,
    required List<ReturnLineInput> lines,
  }) async {
    final returnItem = await _source.createReturn(
      invoiceId: invoiceId,
      customerId: customerId,
      customerName: customerName,
      reason: reason,
      lines: [
        for (final l in lines)
          domain.ReturnLineInput(
            productId: l.productId,
            invoiceLineId: l.invoiceLineId,
            quantity: l.quantity,
            unitPrice: l.unitPrice,
            productSku: l.productSku,
            productName: l.productName,
          ),
      ],
    );
    return returnItem.toDto();
  }
}
