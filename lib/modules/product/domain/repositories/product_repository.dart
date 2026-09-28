import '../entities/product.dart';
import '../entities/product_query.dart';
import '../entities/category.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getProducts(ProductQuery query);

  Future<Product?> getProductById(String id);

  Future<Product> createProduct(Product product, {required int initialStock});

  Future<List<Category>> getCategories();

  Future<Category> createCategory(String name);

  Future<Product> updateProduct(Product product);

  Future<void> deactivateProduct(String id);

  Future<void> saveCatalogOrder({
    required List<String> productIds,
    required List<String> categoryIds,
  });
}
