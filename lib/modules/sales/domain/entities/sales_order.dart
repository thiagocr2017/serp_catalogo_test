enum OrderStatus { draft, confirmed, reserved, dispatched, delivered, cancelled }

class SalesOrder {
  const SalesOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    this.customerId,
    this.exchangeRate = 1.0,
    this.notes,
    this.agentId,
    this.quoteId,
    this.inventoryDocumentId,
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
    this.cancelledAt,
  });

  final String id;
  final String orderNumber;
  final String customerName;
  final OrderStatus status;
  final double totalAmount;
  final String currencyCode;
  final String? customerId;
  final double exchangeRate;
  final String? notes;
  final String? agentId;
  final String? quoteId;
  final String? inventoryDocumentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
}

class SalesOrderLine {
  const SalesOrderLine({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.discountPercent = 0,
    this.productSku,
    this.productName,
  });

  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double discountPercent;
  final String? productSku;
  final String? productName;
}
