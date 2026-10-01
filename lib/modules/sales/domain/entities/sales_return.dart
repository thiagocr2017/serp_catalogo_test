enum ReturnStatus { draft, confirmed, cancelled }

class SalesReturn {
  const SalesReturn({
    required this.id,
    required this.returnNumber,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    required this.reason,
    this.invoiceId,
    this.customerId,
    this.notes,
    this.inventoryDocumentId,
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
  });

  final String id;
  final String returnNumber;
  final String customerName;
  final ReturnStatus status;
  final double totalAmount;
  final String currencyCode;
  final String reason;
  final String? invoiceId;
  final String? customerId;
  final String? notes;
  final String? inventoryDocumentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
}

class SalesReturnLine {
  const SalesReturnLine({
    required this.id,
    required this.returnId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.productSku,
    this.productName,
  });

  final String id;
  final String returnId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? productSku;
  final String? productName;
}
