import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/device/device_identity.dart';
import 'package:serp/modules/product/data/data_sources/supabase_product_data_source.dart';
import 'package:serp/modules/product/data/models/product_model.dart';
import 'package:serp/modules/product/data/repositories/supabase_product_repository.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _unusedClient = SupabaseClient('http://localhost:54321', 'test-key');

class _RecordingProductDataSource extends SupabaseProductDataSource {
  _RecordingProductDataSource()
    : super(
        _unusedClient,
        const DeviceIdentity(
          name: 'Equipo de prueba',
          identifier: 'device-001',
        ),
      );

  Map<String, dynamic>? values;
  int? initialStock;

  @override
  Future<ProductModel> createProduct(
    Map<String, dynamic> input, {
    required int initialStock,
  }) async {
    values = input;
    this.initialStock = initialStock;
    return ProductModel({
      ...input,
      'current_stock': initialStock,
      'created_at': '2026-09-29T00:00:00.000Z',
    });
  }
}

void main() {
  test(
    'product repository forwards initial stock with the creation payload',
    () async {
      final source = _RecordingProductDataSource();
      final repository = SupabaseProductRepository(source);
      final product = Product(
        id: 'product-001',
        sku: 'SKU-001',
        name: 'Producto de prueba',
        description: 'Descripción',
        categoryId: 'category-001',
        unitPriceInCents: 1250,
        minimumOrderQuantity: 2,
        packagingPresentationId: 'presentation-001',
        cbmPerMoq: 0.25,
        factoryCostInCents: 500,
        currentStock: 0,
        reorderPoint: 3,
        isActive: true,
        createdAt: DateTime.utc(2026, 9, 29),
      );

      final created = await repository.createProduct(product, initialStock: 12);

      expect(source.initialStock, 12);
      expect(source.values!['id'], 'product-001');
      expect(source.values!['sku'], 'SKU-001');
      expect(source.values!['unit_price'], 12.5);
      expect(source.values!['packaging_presentation_id'], 'presentation-001');
      expect(created.currentStock, 12);
    },
  );
}
