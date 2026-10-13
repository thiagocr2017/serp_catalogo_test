enum SalesInvoiceStatus { draft, confirmed, cancelled, paid }

class SalesInvoice {
  const SalesInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    this.customerId,
    this.sourceQuoteId,
    this.exchangeRate = 1.0,
    this.notes,
    this.inventoryDocumentId,
    this.lines = const [],
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
    this.cancelledAt,
  });

  final String id;
  final String invoiceNumber;
  final String customerName;
  final SalesInvoiceStatus status;
  final double totalAmount;
  final String currencyCode;
  final String? customerId;
  final String? sourceQuoteId;
  final double exchangeRate;
  final String? notes;
  final String? inventoryDocumentId;
  final List<SalesInvoiceLine> lines;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
}

class SalesInvoiceLine {
  const SalesInvoiceLine({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.discountPercent = 0,
    this.productSku,
    this.productName,
  });

  final String id;
  final String invoiceId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double discountPercent;
  final String? productSku;
  final String? productName;
}
