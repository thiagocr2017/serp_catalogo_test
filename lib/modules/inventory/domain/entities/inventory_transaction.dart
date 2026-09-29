enum InventoryReason {
  initialStock,
  purchase,
  sale,
  adjustment,
  returnItem,
  reversal,
  transferOut,
  transferIn,
}

int signedInventoryQuantity({
  required int enteredQuantity,
  required InventoryReason reason,
}) => switch (reason) {
  InventoryReason.sale || InventoryReason.transferOut => -enteredQuantity.abs(),
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
    required this.warehouseId,
    required this.locationId,
    required this.commandId,
    this.productSku,
    this.warehouseName,
    this.locationName,
    this.notes,
    this.reversalOfTransactionId,
    this.documentId,
    this.documentNumber,
  });
  final String id;
  final String productId;
  final String? productSku;
  final int quantity;
  final InventoryReason reason;
  final String warehouseId;
  final String locationId;
  final String commandId;
  final String? warehouseName;
  final String? locationName;
  final String? notes;
  final String? reversalOfTransactionId;
  final String? documentId;
  final String? documentNumber;
  final DateTime createdAt;
}
