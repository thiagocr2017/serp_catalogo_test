import '../entities/sales_consignment.dart';

abstract interface class ConsignmentRepository {
  Future<List<SalesConsignment>> getConsignments();
  Future<SalesConsignment?> getConsignmentById(String id);
  Future<SalesConsignment> createConsignment({
    required String customerId,
    required String customerName,
    required String currencyCode,
    String? notes,
    String? agentId,
    required List<ConsignmentLineInput> lines,
    required String warehouseId,
    required String? locationId,
  });
  Future<SalesConsignment> registerReturn({
    required String consignmentId,
    required String productId,
    required int quantity,
  });
}

class ConsignmentLineInput {
  const ConsignmentLineInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.productSku,
    this.productName,
  });

  final String productId;
  final int quantity;
  final double unitPrice;
  final String? productSku;
  final String? productName;
}
