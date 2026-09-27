import '../entities/product.dart';
import '../repositories/product_repository.dart';

class SaveProduct {
  const SaveProduct(this._repository);

  final ProductRepository _repository;

  Future<Product> create(Product product) => _repository.createProduct(product);

  Future<Product> update(Product product) => _repository.updateProduct(product);
}
