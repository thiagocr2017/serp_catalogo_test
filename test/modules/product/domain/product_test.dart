import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/product/product_module.dart';

void main() {
  group('Product stock status', () {
    Product createProduct({required int stock, int reorderPoint = 5}) {
      return Product(
        id: 'product-id',
        sku: 'SKU-001',
        name: 'Product',
        description: 'Description',
        categoryId: 'category-id',
        unitPriceInCents: 100,
        minimumOrderQuantity: 1,
        packagingType: PackagingType.unit,
        cbmPerMoq: 0.01,
        factoryCostInCents: 50,
        currentStock: stock,
        reorderPoint: reorderPoint,
        isActive: true,
        createdAt: DateTime.utc(2026),
      );
    }

    test('reports a product with zero stock as out of stock', () {
      final product = createProduct(stock: 0);

      expect(product.isOutOfStock, isTrue);
    });

    test('reports stock at the reorder point as requiring restock', () {
      final product = createProduct(stock: 5);

      expect(product.requiresRestock, isTrue);
    });
  });
}
