class InventoryBalance {
  const InventoryBalance({
    required this.productId,
    required this.warehouseId,
    required this.locationId,
    required this.quantity,
    this.reservedQuantity = 0,
    this.productSku,
    this.warehouseName,
    this.locationName,
  });

  final String productId;
  final String warehouseId;
  final String locationId;
  final int quantity;
  final int reservedQuantity;
  final String? productSku;
  final String? warehouseName;
  final String? locationName;
}
