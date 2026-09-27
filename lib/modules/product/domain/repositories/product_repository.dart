import '../entities/product.dart';
import '../entities/product_query.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getProducts(ProductQuery query);

  Future<Product?> getProductById(String id);

  Future<Product> createProduct(Product product);

  Future<Product> updateProduct(Product product);

  Future<void> deactivateProduct(String id);
}
