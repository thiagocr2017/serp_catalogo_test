import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/product_api.dart';
import '../domain/entities/product.dart';
import '../domain/entities/product_query.dart';
import '../domain/repositories/product_repository.dart';
import '../domain/use_cases/deactivate_product.dart';
import '../domain/use_cases/get_product_by_id.dart';
import '../domain/use_cases/get_products.dart';
import '../domain/use_cases/save_product.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  throw StateError(
    'ProductRepository must be overridden during application bootstrap.',
  );
});

final getProductsProvider = Provider<GetProducts>((ref) {
  return GetProducts(ref.watch(productRepositoryProvider));
});

final getProductByIdProvider = Provider<GetProductById>((ref) {
  return GetProductById(ref.watch(productRepositoryProvider));
});

final saveProductProvider = Provider<SaveProduct>((ref) {
  return SaveProduct(ref.watch(productRepositoryProvider));
});

final deactivateProductProvider = Provider<DeactivateProduct>((ref) {
  return DeactivateProduct(ref.watch(productRepositoryProvider));
});

final productApiProvider = Provider<ProductApi>((ref) {
  return _ProductApiAdapter(
    getProductsUseCase: ref.watch(getProductsProvider),
    getProductByIdUseCase: ref.watch(getProductByIdProvider),
  );
});

class _ProductApiAdapter implements ProductApi {
  const _ProductApiAdapter({
    required this.getProductsUseCase,
    required this.getProductByIdUseCase,
  });

  final GetProducts getProductsUseCase;
  final GetProductById getProductByIdUseCase;

  @override
  Future<List<Product>> getProducts([
    ProductQuery query = const ProductQuery(),
  ]) {
    return getProductsUseCase(query);
  }

  @override
  Future<Product?> getProductById(String id) => getProductByIdUseCase(id);
}
