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
