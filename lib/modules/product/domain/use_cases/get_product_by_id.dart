import '../entities/product.dart';
import '../repositories/product_repository.dart';

class GetProductById {
  const GetProductById(this._repository);

  final ProductRepository _repository;

  Future<Product?> call(String id) => _repository.getProductById(id);
}
