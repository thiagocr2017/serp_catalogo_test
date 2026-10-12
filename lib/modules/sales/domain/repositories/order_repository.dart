import '../entities/sales_order.dart';

abstract interface class OrderRepository {
  Future<List<SalesOrder>> getOrders();
  Future<SalesOrder?> getOrderById(String id);
  Future<SalesOrder> createOrder({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    String? agentId,
    String? quoteId,
    required List<OrderLineInput> lines,
    required String warehouseId,
    required String? locationId,
  });
  Future<SalesOrder> cancelOrder(String id);
}

class OrderLineInput {
  const OrderLineInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    this.productSku,
    this.productName,
  });

  final String productId;
  final int quantity;
  final double unitPrice;
  final double discountPercent;
  final String? productSku;
  final String? productName;
}
