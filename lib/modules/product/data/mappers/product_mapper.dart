import '../../domain/entities/product.dart';
import '../models/product_model.dart';

extension ProductModelMapper on ProductModel {
  Product toDomain() {
    return Product(
      id: id,
      sku: sku,
      barcode: barcode,
      name: name,
      description: description,
      categoryId: categoryId,
      unitPriceInCents: unitPriceInCents,
      packagePriceInCents: packagePriceInCents,
      minimumOrderQuantity: minimumOrderQuantity,
      minimumSaleQuantity: minimumSaleQuantity,
      packagingType: PackagingType.values.byName(packagingType.toLowerCase()),
      packagingPresentationId: packagingPresentationId,
      packagingPresentationName: packagingPresentationName,
      cbmPerMoq: cbmPerMoq,
      factoryCostInCents: factoryCostInCents,
      imageUrl: imageUrl,
      imagePositionX: imagePositionX,
      imagePositionY: imagePositionY,
      imageScale: imageScale,
      catalogSortOrder: catalogSortOrder,
      currentStock: currentStock,
      reorderPoint: reorderPoint,
      promotionPriceInCents: promotionPriceInCents,
      promotionText: promotionText,
      promotionType: promotionType == null
          ? null
          : PromotionType.values.byName(promotionType!),
      bulkPromotionId: bulkPromotionId,
      bulkPromotionName: bulkPromotionName,
      bulkPromotionConditions: bulkPromotionConditions,
      bulkProductConditions: bulkProductConditions,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }
}

extension ProductToDataMapper on Product {
  Map<String, dynamic> toPersistence() {
    return {
      'id': id,
      'sku': sku,
      'barcode': barcode,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'unit_price': unitPriceInCents / 100,
      'package_price': packagePriceInCents == null
          ? null
          : packagePriceInCents! / 100,
      'min_order_quantity': minimumOrderQuantity,
      'minimum_sale_quantity': minimumSaleQuantity,
      'packaging_type': packagingType.name.toUpperCase(),
      'packaging_presentation_id': packagingPresentationId,
      'cbm_per_moq': cbmPerMoq,
      'factory_cost': factoryCostInCents / 100,
      'image_url': imageUrl,
      'image_position_x': imagePositionX,
      'image_position_y': imagePositionY,
      'image_scale': imageScale,
      'catalog_sort_order': catalogSortOrder,
      'reorder_point': reorderPoint,
      'promo_price':
          promotionType == PromotionType.bulk || promotionPriceInCents == null
          ? null
          : promotionPriceInCents! / 100,
      'promo_text': promotionType == PromotionType.bulk ? null : promotionText,
      'is_active': isActive,
    };
  }
}
