import '../domain/entities/product.dart';
import '../domain/entities/product_query.dart';

abstract interface class ProductApi {
  Future<List<Product>> getProducts([
    ProductQuery query = const ProductQuery(),
  ]);

  Future<Product?> getProductById(String id);
}
