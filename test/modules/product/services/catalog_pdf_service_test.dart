import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/services/catalog_pdf_service.dart';

void main() {
  test('catalog excludes inactive and out-of-stock products', () {
    Product product(String id, {required bool active, required int stock}) =>
        Product(
          id: id,
          sku: 'SKU-$id',
          name: 'Producto $id',
          description: 'Descripción',
          categoryId: 'category-id',
          unitPriceInCents: 100,
          minimumOrderQuantity: 1,
          packagingType: PackagingType.unit,
          cbmPerMoq: 0,
          factoryCostInCents: 50,
          currentStock: stock,
          reorderPoint: 1,
          isActive: active,
          createdAt: DateTime.utc(2026),
        );

    final eligible = eligibleCatalogProducts([
      product('active', active: true, stock: 2),
      product('inactive', active: false, stock: 2),
      product('empty', active: true, stock: 0),
    ]);

    expect(eligible.map((product) => product.id), ['active']);
  });

  test('generates a local PDF with category sections', () async {
    final product = Product(
      id: 'product-id',
      sku: 'SKU-1',
      name: 'Producto',
      description: 'Descripción',
      categoryId: 'category-id',
      unitPriceInCents: 1099,
      minimumOrderQuantity: 1,
      packagingType: PackagingType.unit,
      cbmPerMoq: 0,
      factoryCostInCents: 500,
      currentStock: 10,
      reorderPoint: 2,
      isActive: true,
      createdAt: DateTime.utc(2026),
    );

    final bytes = await CatalogPdfService().generate(
      [product],
      const CatalogPdfOptions(
        companyName: 'SERP',
        paymentMethods: 'Transferencia',
        agentName: 'Agente',
        agentPhone: '+506 8888 8888',
        cardsPerPage: 0,
        categoryNames: {'category-id': 'Categoría'},
        backgroundColor: '#F5F5F5',
        cardColor: '#FFFFFF',
        accentColor: '#1565C0',
        textColor: '#111111',
        highlightTextColor: '#0D47A1',
        secondaryTextColor: '#616161',
        promotionColor: '#C62828',
        promotionTextColor: '#FFFFFF',
        imageFit: CatalogImageFit.contain,
      ),
    );

    expect(bytes.take(4), orderedEquals('%PDF'.codeUnits));
    expect(bytes.length, greaterThan(1000));
  });

  test(
    'generates exactly one product card per page without overflowing',
    () async {
      Product product(String id) => Product(
        id: id,
        sku: 'SKU-$id',
        name: 'Producto $id',
        description: 'Descripción extensa para validar la tarjeta individual.',
        categoryId: 'category-id',
        unitPriceInCents: 1099,
        minimumOrderQuantity: 24,
        minimumSaleQuantity: 2,
        packagingType: PackagingType.unit,
        cbmPerMoq: 0.2,
        factoryCostInCents: 500,
        currentStock: 10,
        reorderPoint: 2,
        isActive: true,
        createdAt: DateTime.utc(2026),
      );

      final bytes = await CatalogPdfService().generate(
        [product('1'), product('2'), product('3')],
        const CatalogPdfOptions(
          companyName: 'SERP',
          paymentMethods: 'Transferencia',
          agentName: 'Agente',
          agentPhone: '+506 8888 8888',
          cardsPerPage: 1,
          categoryNames: {'category-id': 'Categoría'},
        ),
      );

      expect(bytes.take(4), orderedEquals('%PDF'.codeUnits));
      expect(bytes.length, greaterThan(1000));
    },
  );

  test('generates proportional layouts for 2, 4 and 6 cards', () async {
    Product product(int id) => Product(
      id: '$id',
      sku: 'SKU-$id',
      name: 'Producto $id',
      description: 'Descripción del producto para el catálogo.',
      categoryId: 'category-id',
      unitPriceInCents: 1099,
      minimumOrderQuantity: 12,
      packagingType: PackagingType.unit,
      cbmPerMoq: 0.1,
      factoryCostInCents: 500,
      currentStock: 10,
      reorderPoint: 2,
      isActive: true,
      createdAt: DateTime.utc(2026),
    );

    final products = [for (var id = 1; id <= 7; id++) product(id)];
    for (final cardsPerPage in [2, 4, 6]) {
      final bytes = await CatalogPdfService().generate(
        products,
        CatalogPdfOptions(
          companyName: 'SERP',
          paymentMethods: 'Transferencia',
          agentName: 'Agente',
          agentPhone: '+506 8888 8888',
          cardsPerPage: cardsPerPage,
          categoryNames: const {'category-id': 'Categoría'},
        ),
      );

      expect(bytes.take(4), orderedEquals('%PDF'.codeUnits));
      expect(bytes.length, greaterThan(1000));
    }
  });
}
