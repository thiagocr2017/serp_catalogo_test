import '../repositories/product_repository.dart';

class DeactivateProduct {
  const DeactivateProduct(this._repository);

  final ProductRepository _repository;

  Future<void> call(String id) => _repository.deactivateProduct(id);
}
