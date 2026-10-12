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
    this.lines = const [],
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
    this.debtReductionAmount = 0,
    this.financialResolution,
    this.financialResolutionAmount = 0,
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
  final List<SalesReturnLine> lines;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
  final double debtReductionAmount;
  final String? financialResolution;
  final double financialResolutionAmount;
}

class SalesReturnLine {
  const SalesReturnLine({
    required this.id,
    required this.returnId,
    required this.productId,
    this.invoiceLineId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.productSku,
    this.productName,
    this.condition = 'GOOD',
    this.conditionNote,
    this.inventoryLocationId,
  });

  final String id;
  final String returnId;
  final String productId;
  final String? invoiceLineId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? productSku;
  final String? productName;
  final String condition;
  final String? conditionNote;
  final String? inventoryLocationId;
}
