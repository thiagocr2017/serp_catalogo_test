import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/product/data/mappers/product_mapper.dart';
import 'package:serp/modules/product/data/models/product_model.dart';
import 'package:serp/modules/product/domain/entities/product.dart';

void main() {
  test('maps PostgreSQL numeric money values to integer cents', () {
    final product = ProductModel({
      'id': 'product-id',
      'sku': 'SKU-1',
      'barcode': null,
      'name': 'Producto',
      'description': 'Descripción',
      'category_id': 'category-id',
      'unit_price': '10.25',
      'package_price': 20.5,
      'min_order_quantity': 2,
      'minimum_sale_quantity': 5,
      'packaging_type': 'BOX',
      'cbm_per_moq': '0.125',
      'factory_cost': '4.10',
      'image_url': null,
      'image_position_x': '0.25',
      'image_position_y': 0.75,
      'current_stock': 7,
      'reorder_point': 3,
      'promo_price': '8.99',
      'promo_text': 'Oferta',
      'promotion_type': 'bulk',
      'is_active': true,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': null,
      'deleted_at': null,
    }).toDomain();

    expect(product.unitPriceInCents, 1025);
    expect(product.packagePriceInCents, 2050);
    expect(product.factoryCostInCents, 410);
    expect(product.promotionPriceInCents, 899);
    expect(product.promotionType, PromotionType.bulk);
    expect(product.minimumOrderQuantity, 2);
    expect(product.minimumSaleQuantity, 5);
    expect(product.imagePositionX, 0.25);
    expect(product.imagePositionY, 0.75);

    final persistence = product.toPersistence();
    expect(persistence['promo_price'], isNull);
    expect(persistence['promo_text'], isNull);
    expect(persistence['image_position_x'], 0.25);
    expect(persistence['image_position_y'], 0.75);
  });
}
