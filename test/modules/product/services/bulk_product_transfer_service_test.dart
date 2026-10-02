import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:serp/modules/product/data/data_sources/supabase_product_data_source.dart';
import 'package:serp/modules/product/data/repositories/supabase_product_repository.dart';
import 'package:serp/modules/product/domain/entities/category.dart';
import 'package:serp/modules/product/services/bulk_product_transfer_service.dart';
import 'package:serp/modules/product/services/product_image_service.dart';
import 'package:serp/core/device/device_identity.dart';
import 'package:serp/modules/configuration/configuration_module.dart';

void main() {
  test('Excel CSV template can be parsed with BOM and semicolon delimiter', () {
    final client = SupabaseClient('http://127.0.0.1:54321', 'test-key');
    final service = BulkProductTransferService(
      SupabaseProductRepository(
        SupabaseProductDataSource(
          client,
          const DeviceIdentity(name: 'test', identifier: 'test'),
        ),
      ),
      ProductImageService(client),
    );
    final csv =
        '${service.templateCsv()}\r\n'
        'ABC-1;Producto;Descripción;General;;12.50;;1;Unidad;1;0;5;3;2;SI;ABC-1.jpg';
    final preview = service.parseCsv(
      csv,
      categories: const [
        Category(id: 'cat-1', name: 'General', isActive: true),
      ],
      existingProducts: const [],
      presentations: const [
        PackagingPresentationDto(
          id: 'unit',
          name: 'Unidad',
          sortOrder: 0,
          isActive: true,
          version: 1,
        ),
      ],
    );

    expect(preview.errors, isEmpty);
    expect(preview.rows, hasLength(1));
    expect(preview.rows.single.sku, 'ABC-1');
    expect(preview.rows.single.unitPriceInCents, 1250);
    expect(preview.rows.single.initialStock, 3);
  });
}
