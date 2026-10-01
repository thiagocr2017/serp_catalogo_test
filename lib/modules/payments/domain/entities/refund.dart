enum RefundStatus { pending, confirmed, rejected }

class Refund {
  const Refund({
    required this.id,
    required this.paymentId,
    required this.amount,
    required this.currencyCode,
    required this.reason,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String paymentId;
  final double amount;
  final String currencyCode;
  final String reason;
  final RefundStatus status;
  final DateTime? createdAt;
}
