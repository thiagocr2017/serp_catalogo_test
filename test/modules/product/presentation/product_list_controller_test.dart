import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/product/di/product_providers.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/domain/entities/category.dart';
import 'package:serp/modules/product/domain/entities/product_query.dart';
import 'package:serp/modules/product/domain/repositories/product_repository.dart';
import 'package:serp/modules/product/presentation/controllers/product_list_controller.dart';

void main() {
  test('loads products through the repository override', () async {
    final repository = _InMemoryProductRepository();
    final container = ProviderContainer(
      overrides: [productRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final products = await container.read(productListControllerProvider.future);

    expect(products, hasLength(1));
    expect(products.single.sku, 'SKU-001');
  });
}

class _InMemoryProductRepository implements ProductRepository {
  final List<Product> _products = [
    Product(
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
      currentStock: 10,
      reorderPoint: 5,
      isActive: true,
      createdAt: DateTime.utc(2026),
    ),
  ];

  @override
  Future<Product> createProduct(
    Product product, {
    required int initialStock,
  }) async => product;

  @override
  Future<List<Category>> getCategories() async => const [];

  @override
  Future<Category> createCategory(String name) async =>
      Category(id: 'category-id', name: name, isActive: true);

  @override
  Future<void> deactivateProduct(String id) async {}

  @override
  Future<Product?> getProductById(String id) async =>
      _products.where((product) => product.id == id).firstOrNull;

  @override
  Future<List<Product>> getProducts(ProductQuery query) async => _products;

  @override
  Future<Product> updateProduct(Product product) async => product;
}
