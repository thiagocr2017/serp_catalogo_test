import '../entities/sales_return.dart';

abstract interface class ReturnRepository {
  Future<List<SalesReturn>> getReturns();
  Future<SalesReturn?> getReturnById(String id);
  Future<SalesReturn> createReturn({
    required String invoiceId,
    required String customerId,
    required String customerName,
    required String reason,
    required List<ReturnLineInput> lines,
  });
}

class ReturnLineInput {
  const ReturnLineInput({
    required this.productId,
    required this.invoiceLineId,
    required this.quantity,
    required this.unitPrice,
    this.productSku,
    this.productName,
  });

  final String productId;
  final String invoiceLineId;
  final int quantity;
  final double unitPrice;
  final String? productSku;
  final String? productName;
}
