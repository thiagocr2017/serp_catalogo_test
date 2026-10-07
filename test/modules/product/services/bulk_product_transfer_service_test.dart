import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:serp/modules/product/data/data_sources/supabase_product_data_source.dart';
import 'package:serp/modules/product/data/repositories/supabase_product_repository.dart';
import 'package:serp/modules/product/domain/entities/category.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/services/bulk_product_transfer_service.dart';
import 'package:serp/modules/product/services/product_image_service.dart';
import 'package:serp/core/device/device_identity.dart';
import 'package:serp/modules/configuration/configuration_module.dart';

void main() {
  test('CSV preserves category and product catalog order', () {
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
    const category = Category(
      id: 'cat-1',
      name: 'General',
      isActive: true,
      catalogSortOrder: 4,
    );
    final csv =
        '${service.templateCsv()}\r\n'
        'ABC-1;Producto;Descripción;General;;12.50;;1;Unidad;1;0;5;3;2;SI;ABC-1.jpg;4;7';
    final preview = service.parseCsv(
      '\ufeff$csv',
      categories: const [category],
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
    expect(preview.rows.single.categorySortOrder, 4);
    expect(preview.rows.single.catalogSortOrder, 7);

    final exported = service.exportCsv(
      [
        Product(
          id: 'product-1',
          sku: 'ABC-1',
          name: 'Producto',
          description: 'Descripción',
          categoryId: category.id,
          unitPriceInCents: 1250,
          minimumOrderQuantity: 1,
          packagingPresentationId: 'unit',
          packagingPresentationName: 'Unidad',
          cbmPerMoq: 0,
          factoryCostInCents: 500,
          currentStock: 3,
          reorderPoint: 2,
          isActive: true,
          createdAt: DateTime.utc(2026),
          catalogSortOrder: 7,
        ),
      ],
      const [category],
    );
    final roundTrip = service.parseCsv(
      exported,
      categories: const [category],
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
    expect(roundTrip.errors, isEmpty);
    expect(roundTrip.rows.single.categorySortOrder, 4);
    expect(roundTrip.rows.single.catalogSortOrder, 7);
  });

  test('old CSV without order columns keeps compatible defaults', () {
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
    final legacyHeaders = BulkProductTransferService.headers
        .where(
          (header) => header != 'orden_categoria' && header != 'orden_producto',
        )
        .toList();
    final csv =
        '${legacyHeaders.join(';')}\n'
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
    expect(preview.rows.single.categorySortOrder, 0);
    expect(preview.rows.single.catalogSortOrder, 0);
  });
}
