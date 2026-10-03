import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'product_dtos.dart';

export 'product_dtos.dart';

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
  /// Listado publico de productos. Devuelve el DTO publico, no la entidad de
  /// dominio: un cambio interno de `Product` no debe romper al consumidor.
  Future<List<ProductSummaryDto>> listProducts([
    ProductListQuery query = const ProductListQuery(),
  ]);

  /// Resumen de un producto por su identificador opaco, o `null` si no existe.
  Future<ProductSummaryDto?> getProductSummary(String id);
}
