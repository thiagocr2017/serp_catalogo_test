enum PackagingType { unit, box, set }

enum PromotionType { individual, bulk }

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.unitPriceInCents,
    required this.minimumOrderQuantity,
    this.minimumSaleQuantity = 1,
    required this.packagingType,
    this.packagingPresentationId,
    this.packagingPresentationName,
    required this.cbmPerMoq,
    required this.factoryCostInCents,
    required this.currentStock,
    required this.reorderPoint,
    required this.isActive,
    required this.createdAt,
    this.barcode,
    this.packagePriceInCents,
    this.imageUrl,
    this.imagePositionX = 0.5,
    this.imagePositionY = 0.5,
    this.imageScale = 1,
    this.catalogSortOrder = 0,
    this.promotionPriceInCents,
    this.promotionText,
    this.promotionType,
    this.bulkPromotionId,
    this.bulkPromotionName,
    this.bulkPromotionConditions,
    this.bulkProductConditions,
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
  final int minimumSaleQuantity;
  final PackagingType packagingType;
  final String? packagingPresentationId;
  final String? packagingPresentationName;
  final double cbmPerMoq;
  final int factoryCostInCents;
  final String? imageUrl;
  final double imagePositionX;
  final double imagePositionY;
  final double imageScale;
  final int catalogSortOrder;
  final int currentStock;
  final int reorderPoint;
  final int? promotionPriceInCents;
  final String? promotionText;
  final PromotionType? promotionType;
  final String? bulkPromotionId;
  final String? bulkPromotionName;
  final String? bulkPromotionConditions;
  final String? bulkProductConditions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  bool get isOutOfStock => currentStock <= 0;

  bool get requiresRestock => currentStock <= reorderPoint;
}
