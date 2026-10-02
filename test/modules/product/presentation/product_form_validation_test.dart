import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/configuration/configuration_module.dart';
import 'package:serp/modules/product/di/product_providers.dart';
import 'package:serp/modules/product/domain/entities/category.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/domain/entities/product_query.dart';
import 'package:serp/modules/product/domain/repositories/product_repository.dart';
import 'package:serp/modules/product/presentation/pages/product_form_page.dart';

void main() {
  testWidgets('producto invalido muestra errores y no guarda', (tester) async {
    final repository = _RecordingProductRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(repository),
          configurationApiProvider.overrideWithValue(_FakeConfigurationApi()),
        ],
        child: const MaterialApp(home: ProductFormPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Guardar producto'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();

    expect(find.text('Campo requerido'), findsWidgets);
    expect(find.text('Seleccione una categoría'), findsOneWidget);
    expect(repository.createdProducts, 0);
    expect(find.text('Nuevo producto'), findsOneWidget);
  });
}

class _RecordingProductRepository implements ProductRepository {
  int createdProducts = 0;

  @override
  Future<Product> createProduct(
    Product product, {
    required int initialStock,
  }) async {
    createdProducts++;
    return product;
  }

  @override
  Future<List<Category>> getCategories() async => const [
    Category(id: 'category-1', name: 'General', isActive: true),
  ];

  @override
  Future<Category> createCategory(String name) async =>
      Category(id: 'category-new', name: name, isActive: true);

  @override
  Future<Category> updateCategory(String id, String name) async =>
      Category(id: id, name: name, isActive: true);

  @override
  Future<void> deleteCategory({
    required String categoryId,
    String? replacementCategoryId,
  }) async {}

  @override
  Future<void> deactivateProduct(String id) async {}

  @override
  Future<Product?> getProductById(String id) async => null;

  @override
  Future<List<Product>> getProducts(ProductQuery query) async => const [];

  @override
  Future<Product> updateProduct(Product product) async => product;

  @override
  Future<void> saveCatalogOrder({
    required List<String> productIds,
    required List<String> categoryIds,
  }) async {}
}

class _FakeConfigurationApi implements ConfigurationApi {
  @override
  Future<BusinessSettingsDto> getBusinessSettings() async =>
      const BusinessSettingsDto(
        defaultCurrency: 'USD',
        decimalPlaces: 2,
        taxPercentage: '0',
        pricesIncludeTax: false,
        roundingMode: 'HALF_UP',
        roundingIncrement: '0.01',
        companyName: '',
        paymentMethods: '',
        version: 1,
      );

  @override
  Future<CatalogPreferencesDto> getCatalogPreferences() async =>
      const CatalogPreferencesDto(
        cardsPerPage: 4,
        backgroundColor: '#FFFFFF',
        cardColor: '#FFFFFF',
        designAccentColor: '#3949AB',
        textColor: '#111111',
        highlightTextColor: '#1565C0',
        secondaryTextColor: '#616161',
        promotionColor: '#C62828',
        promotionTextColor: '#FFFFFF',
        promotionPreviousPriceColor: '#757575',
        promotionPriceColor: '#C62828',
        promotionDescriptionColor: '#C62828',
        imageFit: 'cover',
        logoObjectName: null,
        logoVersion: 1,
        selectedAgentId: null,
        version: 1,
      );

  @override
  Future<List<PackagingPresentationDto>> getPackagingPresentations() async =>
      const [
        PackagingPresentationDto(
          id: 'presentation-1',
          name: 'Unidad',
          sortOrder: 0,
          isActive: true,
          version: 1,
        ),
      ];

  @override
  Future<BusinessSettingsDto> saveBusinessSettings(
    SaveBusinessSettingsCommand command,
  ) async => getBusinessSettings();

  @override
  Future<CatalogPreferencesDto> saveCatalogPreferences(
    SaveCatalogPreferencesCommand command,
  ) async => getCatalogPreferences();

  @override
  Future<CatalogPreferencesDto> selectCatalogAgent(
    SelectCatalogAgentCommand command,
  ) async => getCatalogPreferences();

  @override
  Future<PackagingPresentationDto> createPackagingPresentation(
    CreatePackagingPresentationCommand command,
  ) async => const PackagingPresentationDto(
    id: 'presentation-new',
    name: 'Nueva',
    sortOrder: 1,
    isActive: true,
    version: 1,
  );

  @override
  Future<PackagingPresentationDto> updatePackagingPresentation(
    UpdatePackagingPresentationCommand command,
  ) async => PackagingPresentationDto(
    id: command.id,
    name: command.name,
    sortOrder: 0,
    isActive: true,
    version: command.expectedVersion + 1,
  );

  @override
  Future<CatalogLogoReferenceDto> replaceCatalogLogo(
    ReplaceCatalogLogoCommand command,
  ) async => CatalogLogoReferenceDto(
    objectName: 'catalog-logo/${command.operationId}',
    version: command.expectedVersion + 1,
  );

  @override
  Future<Uint8List?> downloadCatalogLogo() async => null;
}
