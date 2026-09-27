import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/services/catalog_pdf_service.dart';

void main() {
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
      ),
    );

    expect(bytes.take(4), orderedEquals('%PDF'.codeUnits));
    expect(bytes.length, greaterThan(1000));
  });
}
