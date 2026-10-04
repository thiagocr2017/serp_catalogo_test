enum ConsignmentStatus {
  draft,
  sent,
  partialReturn,
  returned,
  settled,
  cancelled,
}

class SalesConsignment {
  const SalesConsignment({
    required this.id,
    required this.consignmentNumber,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    this.customerId,
    this.returnedAmount = 0,
    this.notes,
    this.agentId,
    this.inventoryDocumentId,
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
  });

  final String id;
  final String consignmentNumber;
  final String customerName;
  final ConsignmentStatus status;
  final double totalAmount;
  final String currencyCode;
  final String? customerId;
  final double returnedAmount;
  final String? notes;
  final String? agentId;
  final String? inventoryDocumentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
}

class SalesConsignmentLine {
  const SalesConsignmentLine({
    required this.id,
    required this.consignmentId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.returnedQuantity = 0,
    this.productSku,
    this.productName,
  });

  final String id;
  final String consignmentId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final int returnedQuantity;
  final String? productSku;
  final String? productName;
}
