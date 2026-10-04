import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  testWidgets('producto rechaza numeros invalidos antes de guardar', (
    tester,
  ) async {
    final repository = _RecordingProductRepository();

    await tester.pumpWidget(_app(repository, const ProductFormPage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'SKU'), 'SKU-1');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Producto test',
    );
    await _selectOnlyCategory(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio unitario USD'),
      'abc',
    );
    await tester.scrollUntilVisible(
      find.text('Guardar producto'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();

    expect(find.text('Ingrese un número válido'), findsOneWidget);
    expect(repository.createdProducts, 0);
  });

  testWidgets('producto valido se crea con stock inicial', (tester) async {
    final repository = _RecordingProductRepository();

    await tester.pumpWidget(_app(repository, const ProductFormPage()));
    await tester.pumpAndSettle();

    await _fillRequiredProductFields(tester, sku: 'SKU-1', name: 'Producto');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Stock inicial'),
      '8',
    );
    await tester.scrollUntilVisible(
      find.text('Guardar producto'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();

    expect(repository.createdProducts, 1);
    expect(repository.lastInitialStock, 8);
    expect(repository.lastSavedProduct?.sku, 'SKU-1');
    expect(repository.lastSavedProduct?.categoryId, 'category-1');
  });

  testWidgets('producto puede crear categoria rapida y seleccionarla', (
    tester,
  ) async {
    final repository = _RecordingProductRepository();

    await tester.pumpWidget(_app(repository, const ProductFormPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
    await tester.pumpAndSettle();
    expect(find.text('Escriba el nombre.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Retail');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'SKU'), 'SKU-2');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre').last,
      'Producto Retail',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio unitario USD'),
      '12.00',
    );
    await tester.scrollUntilVisible(
      find.text('Guardar producto'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();

    expect(repository.createdCategories, 1);
    expect(repository.lastCategoryName, 'Retail');
    expect(repository.lastSavedProduct?.categoryId, 'category-new');
  });

  testWidgets('producto existente carga y actualiza', (tester) async {
    final repository = _RecordingProductRepository(
      existingProduct: Product(
        id: 'product-1',
        sku: 'SKU-OLD',
        name: 'Producto anterior',
        description: 'Descripción',
        categoryId: 'category-1',
        unitPriceInCents: 1500,
        minimumOrderQuantity: 1,
        minimumSaleQuantity: 1,
        packagingPresentationId: 'presentation-1',
        cbmPerMoq: 0,
        factoryCostInCents: 500,
        currentStock: 4,
        reorderPoint: 1,
        isActive: true,
        createdAt: DateTime.utc(2026),
      ),
    );

    await tester.pumpWidget(
      _app(repository, const ProductFormPage(productId: 'product-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editar producto · SKU-OLD'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Producto anterior'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Producto actualizado',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio unitario USD'),
      '22.50',
    );
    await tester.scrollUntilVisible(
      find.text('Guardar producto'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();

    expect(repository.updatedProducts, 1);
    expect(repository.lastSavedProduct?.id, 'product-1');
    expect(repository.lastSavedProduct?.name, 'Producto actualizado');
    expect(repository.lastSavedProduct?.unitPriceInCents, 2250);
  });
}

class _RecordingProductRepository implements ProductRepository {
  _RecordingProductRepository({this.existingProduct});

  final Product? existingProduct;
  int createdProducts = 0;
  int updatedProducts = 0;
  int createdCategories = 0;
  String? lastCategoryName;
  int? lastInitialStock;
  Product? lastSavedProduct;

  @override
  Future<Product> createProduct(
    Product product, {
    required int initialStock,
  }) async {
    createdProducts++;
    lastInitialStock = initialStock;
    lastSavedProduct = product;
    return product;
  }

  @override
  Future<List<Category>> getCategories() async => const [
    Category(id: 'category-1', name: 'General', isActive: true),
  ];

  @override
  Future<Category> createCategory(String name) async {
    createdCategories++;
    lastCategoryName = name;
    return Category(id: 'category-new', name: name, isActive: true);
  }

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
  Future<Product?> getProductById(String id) async =>
      existingProduct?.id == id ? existingProduct : null;

  @override
  Future<List<Product>> getProducts(ProductQuery query) async => const [];

  @override
  Future<Product> updateProduct(Product product) async {
    updatedProducts++;
    lastSavedProduct = product;
    return product;
  }

  @override
  Future<void> saveCatalogOrder({
    required List<String> productIds,
    required List<String> categoryIds,
  }) async {}
}

Widget _app(ProductRepository repository, Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => child),
      GoRoute(
        path: '/products',
        builder: (_, _) => const Scaffold(body: Text('Productos')),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Producto ${state.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      productRepositoryProvider.overrideWithValue(repository),
      configurationApiProvider.overrideWithValue(_FakeConfigurationApi()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _selectOnlyCategory(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('General').last);
  await tester.pumpAndSettle();
}

Future<void> _fillRequiredProductFields(
  WidgetTester tester, {
  required String sku,
  required String name,
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'SKU'), sku);
  await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), name);
  await _selectOnlyCategory(tester);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Precio unitario USD'),
    '10.00',
  );
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
  Future<List<CarrierDto>> getCarriers() async => const [];

  @override
  Future<List<IdentificationTypeDto>> getIdentificationTypes({
    bool includeInactive = false,
  }) async => const [];

  @override
  Future<IdentificationTypeDto> createIdentificationType(
    CreateIdentificationTypeCommand command,
  ) async => throw UnimplementedError();

  @override
  Future<IdentificationTypeDto> updateIdentificationType(
    UpdateIdentificationTypeCommand command,
  ) async => throw UnimplementedError();

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
  Future<PackagingPresentationDto> deactivatePackagingPresentation(
    DeactivatePackagingPresentationCommand command,
  ) async => PackagingPresentationDto(
    id: command.id,
    name: 'Presentación',
    sortOrder: 0,
    isActive: false,
    version: command.expectedVersion + 1,
  );

  @override
  Future<CarrierDto> saveCarrier(SaveCarrierCommand command) async =>
      CarrierDto(
        id: command.id ?? command.commandId,
        name: command.name,
        phone: command.phone,
        address: command.address,
        contactName: command.contactName,
        notes: command.notes,
        isActive: true,
        version: (command.expectedVersion ?? 0) + 1,
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

  @override
  Future<List<CountryDto>> getCountries() async => const [];

  @override
  Future<List<AdministrativeAreaDto>> getAdministrativeAreas({
    String countryCode = 'CR',
  }) async => const [];

  @override
  Future<List<CityDto>> getCities({
    String countryCode = 'CR',
    String? provinceName,
  }) async => const [];
}
