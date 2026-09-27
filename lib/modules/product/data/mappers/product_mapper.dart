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
      packagingType: PackagingType.values.byName(packagingType.toLowerCase()),
      cbmPerMoq: cbmPerMoq,
      factoryCostInCents: factoryCostInCents,
      imageUrl: imageUrl,
      currentStock: currentStock,
      reorderPoint: reorderPoint,
      promotionPriceInCents: promotionPriceInCents,
      promotionText: promotionText,
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
      'packaging_type': packagingType.name.toUpperCase(),
      'cbm_per_moq': cbmPerMoq,
      'factory_cost': factoryCostInCents / 100,
      'image_url': imageUrl,
      'reorder_point': reorderPoint,
      'promo_price': promotionPriceInCents == null
          ? null
          : promotionPriceInCents! / 100,
      'promo_text': promotionText,
      'is_active': isActive,
    };
  }
}
