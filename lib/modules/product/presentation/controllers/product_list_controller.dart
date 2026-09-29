import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/product_providers.dart';
import '../../api/product_api.dart';

final productListControllerProvider =
    AsyncNotifierProvider<ProductListController, List<Product>>(
      ProductListController.new,
    );

class ProductListController extends AsyncNotifier<List<Product>> {
  ProductQuery _query = const ProductQuery();

  @override
  Future<List<Product>> build() {
    ref.watch(productDataRevisionProvider);
    return ref.watch(getProductsProvider)(_query);
  }

  Future<void> applyQuery(ProductQuery query) async {
    _query = query;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(getProductsProvider)(query));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(getProductsProvider)(_query));
  }
}
