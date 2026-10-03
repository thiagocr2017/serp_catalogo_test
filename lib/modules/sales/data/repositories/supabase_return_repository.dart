import '../../api/return_api.dart';
import '../../domain/repositories/return_repository.dart';
import '../data_sources/supabase_return_data_source.dart';

class SupabaseReturnRepository implements ReturnRepository, ReturnApi {
  const SupabaseReturnRepository(this._source);

  final SupabaseReturnDataSource _source;

  @override
  Future<List<SalesReturn>> getReturns() => _source.getReturns();

  @override
  Future<SalesReturn?> getReturnById(String id) => _source.getReturnById(id);

  @override
  Future<SalesReturn> createReturn({
    required String invoiceId,
    required String customerId,
    required String customerName,
    required String reason,
    required List<ReturnLineInput> lines,
  }) => _source.createReturn(
    invoiceId: invoiceId,
    customerId: customerId,
    customerName: customerName,
    reason: reason,
    lines: lines,
  );
}
