import '../../api/consignment_api.dart';
import '../../domain/repositories/consignment_repository.dart' as domain;
import '../data_sources/supabase_consignment_data_source.dart';
import '../mappers/sales_dto_mapper.dart';

class SupabaseConsignmentApi implements ConsignmentApi {
  const SupabaseConsignmentApi(this._source);

  final SupabaseConsignmentDataSource _source;

  @override
  Future<List<SalesConsignmentDto>> getConsignments() async {
    final consignments = await _source.getConsignments();
    return consignments.map((c) => c.toDto()).toList();
  }

  @override
  Future<SalesConsignmentDto?> getConsignmentById(String id) async {
    final consignment = await _source.getConsignmentById(id);
    return consignment?.toDto();
  }

  @override
  Future<SalesConsignmentDto> createConsignment({
    required String customerId,
    required String customerName,
    required String currencyCode,
    String? notes,
    String? agentId,
    required List<ConsignmentLineInput> lines,
    required String warehouseId,
    required String locationId,
  }) async {
    final consignment = await _source.createConsignment(
      customerId: customerId,
      customerName: customerName,
      currencyCode: currencyCode,
      notes: notes,
      agentId: agentId,
      lines: [
        for (final l in lines)
          domain.ConsignmentLineInput(
            productId: l.productId,
            quantity: l.quantity,
            unitPrice: l.unitPrice,
            productSku: l.productSku,
            productName: l.productName,
          ),
      ],
      warehouseId: warehouseId,
      locationId: locationId,
    );
    return consignment.toDto();
  }

  @override
  Future<SalesConsignmentDto> registerReturn({
    required String consignmentId,
    required String productId,
    required int quantity,
  }) async {
    final consignment = await _source.registerReturn(
      consignmentId: consignmentId,
      productId: productId,
      quantity: quantity,
    );
    return consignment.toDto();
  }
}
