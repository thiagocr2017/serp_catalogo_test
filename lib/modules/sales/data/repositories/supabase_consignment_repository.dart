import '../../api/consignment_api.dart';
import '../../domain/repositories/consignment_repository.dart';
import '../data_sources/supabase_consignment_data_source.dart';

class SupabaseConsignmentRepository
    implements ConsignmentRepository, ConsignmentApi {
  const SupabaseConsignmentRepository(this._source);

  final SupabaseConsignmentDataSource _source;

  @override
  Future<List<SalesConsignment>> getConsignments() =>
      _source.getConsignments();

  @override
  Future<SalesConsignment?> getConsignmentById(String id) =>
      _source.getConsignmentById(id);

  @override
  Future<SalesConsignment> createConsignment({
    required String customerId,
    required String customerName,
    required String currencyCode,
    String? notes,
    String? agentId,
    required List<ConsignmentLineInput> lines,
    required String warehouseId,
    required String locationId,
  }) => _source.createConsignment(
    customerId: customerId,
    customerName: customerName,
    currencyCode: currencyCode,
    notes: notes,
    agentId: agentId,
    lines: lines,
    warehouseId: warehouseId,
    locationId: locationId,
  );

  @override
  Future<SalesConsignment> registerReturn({
    required String consignmentId,
    required String productId,
    required int quantity,
  }) => _source.registerReturn(
    consignmentId: consignmentId,
    productId: productId,
    quantity: quantity,
  );
}
