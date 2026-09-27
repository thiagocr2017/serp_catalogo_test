enum InventoryReason {
  initialStock,
  purchase,
  sale,
  adjustment,
  returnItem,
  reversal,
}

class InventoryTransaction {
  const InventoryTransaction({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.reason,
    required this.createdAt,
    this.notes,
    this.reversalOfTransactionId,
  });
  final String id;
  final String productId;
  final int quantity;
  final InventoryReason reason;
  final String? notes;
  final String? reversalOfTransactionId;
  final DateTime createdAt;
}
