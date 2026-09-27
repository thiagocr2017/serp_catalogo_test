import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inventory/inventory_module.dart';

import '../api/product_api.dart';
import '../domain/entities/product.dart';
import '../domain/entities/product_query.dart';
import '../domain/entities/category.dart';
import '../domain/repositories/product_repository.dart';
import '../domain/use_cases/deactivate_product.dart';
import '../domain/use_cases/get_product_by_id.dart';
import '../domain/use_cases/get_products.dart';
import '../domain/use_cases/save_product.dart';
import '../services/product_image_service.dart';

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

final productByIdProvider = FutureProvider.family<Product?, String>((ref, id) {
  return ref.watch(getProductByIdProvider)(id);
});

final saveProductProvider = Provider<SaveProduct>((ref) {
  return SaveProduct(ref.watch(productRepositoryProvider));
});

final deactivateProductProvider = Provider<DeactivateProduct>((ref) {
  return DeactivateProduct(ref.watch(productRepositoryProvider));
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(productRepositoryProvider).getCategories();
});

final selectedProductIdsProvider =
    NotifierProvider<SelectedProductIds, Set<String>>(SelectedProductIds.new);

class SelectedProductIds extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String id, {required bool selected}) {
    state = selected ? {...state, id} : ({...state}..remove(id));
  }

  void replaceAll(Iterable<String> ids) => state = ids.toSet();

  void clear() => state = <String>{};
}

final productInventoryApiProvider = Provider<InventoryApi>(
  (ref) => throw StateError('InventoryApi must be overridden.'),
);

final productTransactionsProvider =
    FutureProvider.family<List<InventoryTransaction>, String>(
      (ref, productId) => ref
          .watch(productInventoryApiProvider)
          .getTransactions(productId: productId),
    );

final productAuditProvider = FutureProvider.family<List<AuditEntry>, String>(
  (ref, productId) => ref
      .watch(productInventoryApiProvider)
      .getAuditEntries(tableName: 'products', recordId: productId),
);

final productImageServiceProvider = Provider<ProductImageService>(
  (ref) => throw StateError('ProductImageService must be overridden.'),
);

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
