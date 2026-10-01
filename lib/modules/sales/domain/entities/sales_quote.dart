enum QuoteStatus { draft, sent, accepted, rejected, expired, converted }

class SalesQuote {
  const SalesQuote({
    required this.id,
    required this.quoteNumber,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    this.customerId,
    this.exchangeRate = 1.0,
    this.validUntil,
    this.notes,
    this.agentId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String quoteNumber;
  final String customerName;
  final QuoteStatus status;
  final double totalAmount;
  final String currencyCode;
  final String? customerId;
  final double exchangeRate;
  final DateTime? validUntil;
  final String? notes;
  final String? agentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class SalesQuoteLine {
  const SalesQuoteLine({
    required this.id,
    required this.quoteId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.discountPercent = 0,
    this.productSku,
    this.productName,
  });

  final String id;
  final String quoteId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double discountPercent;
  final String? productSku;
  final String? productName;
}
