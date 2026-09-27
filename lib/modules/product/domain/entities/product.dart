enum PackagingType { unit, box, set }

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.unitPriceInCents,
    required this.minimumOrderQuantity,
    required this.packagingType,
    required this.cbmPerMoq,
    required this.factoryCostInCents,
    required this.currentStock,
    required this.reorderPoint,
    required this.isActive,
    required this.createdAt,
    this.barcode,
    this.packagePriceInCents,
    this.imageUrl,
    this.promotionPriceInCents,
    this.promotionText,
    this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String sku;
  final String? barcode;
  final String name;
  final String description;
  final String categoryId;
  final int unitPriceInCents;
  final int? packagePriceInCents;
  final int minimumOrderQuantity;
  final PackagingType packagingType;
  final double cbmPerMoq;
  final int factoryCostInCents;
  final String? imageUrl;
  final int currentStock;
  final int reorderPoint;
  final int? promotionPriceInCents;
  final String? promotionText;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isOutOfStock => currentStock <= 0;

  bool get requiresRestock => currentStock <= reorderPoint;
}
