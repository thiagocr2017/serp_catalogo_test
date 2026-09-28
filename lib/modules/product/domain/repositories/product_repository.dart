import '../entities/product.dart';
import '../entities/product_query.dart';
import '../entities/category.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getProducts(ProductQuery query);

  Future<Product?> getProductById(String id);

  Future<Product> createProduct(Product product, {required int initialStock});

  Future<List<Category>> getCategories();

  Future<Category> createCategory(String name);

  Future<Category> updateCategory(String id, String name);

  Future<void> deleteCategory({
    required String categoryId,
    String? replacementCategoryId,
  });

  Future<Product> updateProduct(Product product);

  Future<void> deactivateProduct(String id);

  Future<void> saveCatalogOrder({
    required List<String> productIds,
    required List<String> categoryIds,
  });
}
