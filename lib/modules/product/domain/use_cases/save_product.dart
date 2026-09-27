import '../entities/product.dart';
import '../repositories/product_repository.dart';

class SaveProduct {
  const SaveProduct(this._repository);

  final ProductRepository _repository;

  Future<Product> create(Product product, {required int initialStock}) =>
      _repository.createProduct(product, initialStock: initialStock);

  Future<Product> update(Product product) => _repository.updateProduct(product);
}
