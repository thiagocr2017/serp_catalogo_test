import 'package:flutter_test/flutter_test.dart';

// Este archivo importa SOLO el indice publico del modulo. Si deja de compilar,
// la superficie publica quedo incompleta y el DTO se dejo fuera de `api/`.
//
// Prueba de frontera exigida por `.specs/architecture/module-security-contract.md` §10 y por
// `.specs/refactors/03-public-dto-migration.md`: un consumidor debe poder
// trabajar importando unicamente `product_module.dart`.
import 'package:serp/modules/product/product_module.dart';

void main() {
  test('el indice publico expone el DTO y la consulta, no la entidad', () {
    const query = ProductListQuery(isActive: true);
    const product = ProductSummaryDto(
      id: 'p-1',
      sku: 'SKU-1',
      name: 'Nombre',
      description: 'Descripcion',
      currentStock: 34,
      unitPriceInCents: 1250,
      packagePriceInCents: 10000,
      packagingPresentationId: 'presentation-1',
      packagingPresentationName: 'Caja',
      minimumSaleQuantity: 2,
      minimumOrderQuantity: 10,
    );

    expect(query.isActive, isTrue);
    expect(product.sku, 'SKU-1');
    expect(product.unitPriceInCents, 1250);
    expect(product.packagingPresentationName, 'Caja');
    expect(product.minimumSaleQuantity, 2);
  });

  test('el indice publico expone la revision de datos y la fachada', () {
    // `productApiProvider` es el registro publico de la fachada; debe seguir
    // accesible desde el indice para que `main.dart` pueda inyectarlo.
    expect(productApiProvider, isNotNull);
  });
}
