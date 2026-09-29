import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/product.dart';
import '../domain/entities/product_query.dart';

export '../domain/entities/product.dart';
export '../domain/entities/product_query.dart';

final productApiProvider = Provider<ProductApi>(
  (ref) => throw StateError('ProductApi must be overridden.'),
);

final productDataRevisionProvider = NotifierProvider<ProductDataRevision, int>(
  ProductDataRevision.new,
);

class ProductDataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void notifyChanged() => state++;
}

abstract interface class ProductApi {
  Future<List<Product>> getProducts([
    ProductQuery query = const ProductQuery(),
  ]);

  Future<Product?> getProductById(String id);
}
