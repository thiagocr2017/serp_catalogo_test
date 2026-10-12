import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/services/catalog_pdf_service.dart';

void main() {
  test('optimizes oversized PDF images without losing transparency', () {
    final source = image.Image(width: 640, height: 480, numChannels: 4);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgba(x, y, x % 256, y % 256, (x + y) % 256, 180);
      }
    }
    final sourceBytes = Uint8List.fromList(image.encodePng(source));

    final optimized = optimizeCatalogImageForPdf(
      sourceBytes,
      maxDimension: 160,
    );
    final decoded = image.decodeImage(optimized)!;

    expect(decoded.width, 160);
    expect(decoded.height, 120);
    expect(decoded.hasAlpha, isTrue);
    expect(optimized.length, lessThan(sourceBytes.length));
  });

  test('does not re-encode an already-small JPEG', () {
    final bytes = Uint8List.fromList(
      image.encodeJpg(image.Image(width: 80, height: 60), quality: 80),
    );

    expect(optimizeCatalogImageForPdf(bytes, maxDimension: 800), same(bytes));
  });

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
          packagingPresentationId: 'presentation-id',
          packagingPresentationName: 'Unidad',
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

  test(
    'reuses cached product image bytes when preview is regenerated',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var requests = 0;
      final imageBytes = image.encodePng(image.Image(width: 2, height: 2));
      server.listen((request) async {
        requests++;
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(imageBytes);
        await request.response.close();
      });

      final product = Product(
        id: 'cached-image-product',
        sku: 'CACHE-1',
        name: 'Producto con imagen',
        description: '',
        categoryId: 'category-id',
        unitPriceInCents: 1000,
        minimumOrderQuantity: 1,
        packagingPresentationId: 'presentation-id',
        cbmPerMoq: 0,
        factoryCostInCents: 500,
        currentStock: 4,
        reorderPoint: 1,
        isActive: true,
        imageUrl: 'http://${server.address.address}:${server.port}/product.png',
        createdAt: DateTime.utc(2026),
      );
      const options = CatalogPdfOptions(
        companyName: 'SERP',
        paymentMethods: 'Transferencia',
        agentName: 'Agente',
        agentPhone: '+506 8888 8888',
        cardsPerPage: 2,
      );
      final service = CatalogPdfService();

      await service.generate([product], options);
      await service.generate([product], options);
      await service.generate([
        Product(
          id: product.id,
          sku: product.sku,
          name: product.name,
          description: product.description,
          categoryId: product.categoryId,
          unitPriceInCents: product.unitPriceInCents,
          minimumOrderQuantity: product.minimumOrderQuantity,
          packagingPresentationId: product.packagingPresentationId,
          cbmPerMoq: product.cbmPerMoq,
          factoryCostInCents: product.factoryCostInCents,
          currentStock: product.currentStock,
          reorderPoint: product.reorderPoint,
          isActive: product.isActive,
          imageUrl: '${product.imageUrl}?v=2',
          createdAt: product.createdAt,
        ),
      ], options);

      expect(requests, 2);
    },
  );

  test('generates a local PDF with category sections', () async {
    final product = Product(
      id: 'product-id',
      sku: 'SKU-1',
      name: 'Producto',
      description: 'Descripción',
      categoryId: 'category-id',
      unitPriceInCents: 1099,
      minimumOrderQuantity: 1,
      packagingPresentationId: 'presentation-id',
      packagingPresentationName: 'Unidad',
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
        packagingPresentationId: 'presentation-id',
        packagingPresentationName: 'Unidad',
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
      packagingPresentationId: 'presentation-id',
      packagingPresentationName: 'Unidad',
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
