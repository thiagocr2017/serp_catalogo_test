import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/product_providers.dart';
import '../../api/product_api.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';

final productListControllerProvider =
    AsyncNotifierProvider<ProductListController, List<Product>>(
      ProductListController.new,
    );

class ProductListController extends AsyncNotifier<List<Product>> {
  ProductQuery _query = const ProductQuery(isActive: true);

  @override
  Future<List<Product>> build() {
    ref.watch(productDataRevisionProvider);
    return ref.watch(getProductsProvider)(_query);
  }

  Future<void> applyQuery(ProductQuery query) async {
    _query = query;
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The provider exposes request errors through its AsyncValue state.
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The provider exposes request errors through its AsyncValue state.
    }
  }
}
