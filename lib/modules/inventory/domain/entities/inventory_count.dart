enum CountStatus { draft, counting, review, confirmed, cancelled }

class InventoryCount {
  const InventoryCount({
    required this.id,
    required this.warehouseId,
    required this.status,
    this.createdAt,
    this.confirmedAt,
  });

  final String id;
  final String warehouseId;
  final CountStatus status;
  final DateTime? createdAt;
  final DateTime? confirmedAt;
}

class InventoryCountLine {
  const InventoryCountLine({
    required this.id,
    required this.countId,
    required this.productId,
    this.locationId,
    this.expectedQuantity,
    this.countedQuantity,
    this.difference,
    this.reviewed = false,
    this.justification,
  });

  final String id;
  final String countId;
  final String productId;
  final String? locationId;
  final int? expectedQuantity;
  final int? countedQuantity;
  final int? difference;
  final bool reviewed;
  final String? justification;
}
