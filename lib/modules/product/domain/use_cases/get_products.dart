import '../entities/product.dart';
import '../entities/product_query.dart';
import '../repositories/product_repository.dart';

class GetProducts {
  const GetProducts(this._repository);

  final ProductRepository _repository;

  Future<List<Product>> call([ProductQuery query = const ProductQuery()]) {
    return _repository.getProducts(query);
  }
}
