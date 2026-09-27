import 'dart:io';

import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/services/catalog_pdf_service.dart';

Future<void> main() async {
  final products = [
    Product(
      id: '1',
      sku: 'HJ300-1',
      name: 'Organizador modular',
      description: 'Organizador plástico apilable para el hogar.',
      categoryId: '1',
      unitPriceInCents: 263,
      minimumOrderQuantity: 12,
      packagingType: PackagingType.box,
      cbmPerMoq: 0.045,
      factoryCostInCents: 120,
      currentStock: 48,
      reorderPoint: 12,
      isActive: true,
      createdAt: DateTime.utc(2026),
    ),
    Product(
      id: '2',
      sku: 'KT100-1',
      name: 'Set de utensilios',
      description: 'Set básico y resistente de utensilios para cocina.',
      categoryId: '2',
      unitPriceInCents: 850,
      minimumOrderQuantity: 6,
      packagingType: PackagingType.set,
      cbmPerMoq: 0.032,
      factoryCostInCents: 410,
      currentStock: 18,
      reorderPoint: 6,
      promotionPriceInCents: 699,
      promotionText: 'Oferta válida hasta agotar existencias.',
      isActive: true,
      createdAt: DateTime.utc(2026),
    ),
  ];
  final bytes = await CatalogPdfService().generate(
    products,
    const CatalogPdfOptions(
      companyName: 'SERP',
      paymentMethods: 'Transferencia bancaria - IBAN USD\nEfectivo y tarjeta',
      agentName: 'Thiago Lopez',
      agentPhone: '+506 8888 8888',
      cardsPerPage: 4,
      categoryNames: {'1': 'Organización', '2': 'Cocina'},
    ),
  );
  final output = File('output/pdf/catalogo_serp_muestra.pdf');
  await output.parent.create(recursive: true);
  await output.writeAsBytes(bytes);
}
