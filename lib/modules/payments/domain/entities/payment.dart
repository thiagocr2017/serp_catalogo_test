enum PaymentStatus { pending, confirmed, cancelled, refunded }

class Payment {
  const Payment({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    this.receiptNumber,
    this.customerName,
    this.customerId,
    this.exchangeRate = 1.0,
    this.notes,
    this.components = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final PaymentStatus status;
  final double totalAmount;
  final String currencyCode;
  final String? receiptNumber;
  final String? customerName;
  final String? customerId;
  final double exchangeRate;
  final String? notes;
  final List<PaymentComponent> components;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class PaymentComponent {
  const PaymentComponent({
    required this.id,
    required this.paymentId,
    required this.currencyCode,
    required this.originalAmount,
    required this.usdEquivalent,
    this.methodId,
    this.moneyAccountId,
    this.exchangeRate = 1.0,
    this.reference,
  });

  final String id;
  final String paymentId;
  final String currencyCode;
  final double originalAmount;
  final double usdEquivalent;
  final String? methodId;
  final String? moneyAccountId;
  final double exchangeRate;
  final String? reference;
}
