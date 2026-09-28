enum InventoryReason {
  initialStock,
  purchase,
  sale,
  adjustment,
  returnItem,
  reversal,
}

int signedInventoryQuantity({
  required int enteredQuantity,
  required InventoryReason reason,
}) => switch (reason) {
  InventoryReason.sale => -enteredQuantity.abs(),
  InventoryReason.adjustment => enteredQuantity,
  _ => enteredQuantity.abs(),
};

class InventoryTransaction {
  const InventoryTransaction({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.reason,
    required this.createdAt,
    this.productSku,
    this.notes,
    this.reversalOfTransactionId,
  });
  final String id;
  final String productId;
  final String? productSku;
  final int quantity;
  final InventoryReason reason;
  final String? notes;
  final String? reversalOfTransactionId;
  final DateTime createdAt;
}
