import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/product/di/product_providers.dart';
import 'package:serp/modules/product/di/promotion_providers.dart';
import 'package:serp/modules/product/domain/entities/bulk_promotion.dart';
import 'package:serp/modules/product/domain/entities/category.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/domain/entities/product_query.dart';
import 'package:serp/modules/product/domain/repositories/product_repository.dart';
import 'package:serp/modules/product/domain/repositories/promotion_repository.dart';
import 'package:serp/modules/product/presentation/pages/promotion_form_page.dart';
import 'package:serp/modules/product/presentation/pages/promotion_page.dart';

void main() {
  testWidgets('lista de promociones filtra desde tres caracteres', (
    tester,
  ) async {
    _setLargeViewport(tester);
    final promotions = _RecordingPromotionRepository(
      initialPromotions: [
        BulkPromotion(
          id: 'liquidacion',
          name: 'Liquidación',
          discountPercentage: 10,
          conditionsText: 'Hasta agotar inventario',
          endDate: DateTime(2027),
          appliesToAllProducts: true,
          isActive: true,
        ),
        BulkPromotion(
          id: 'temporada',
          name: 'Temporada',
          discountPercentage: 15,
          conditionsText: 'Productos seleccionados',
          endDate: DateTime(2027),
          appliesToAllProducts: true,
          isActive: true,
        ),
      ],
    );
    await tester.pumpWidget(_app(promotions));
    await tester.pumpAndSettle();

    final search = _field('Buscar promociones');
    await tester.enterText(search, 'Li');
    await tester.pumpAndSettle();
    expect(find.textContaining('Liquidación'), findsOneWidget);
    expect(find.textContaining('Temporada'), findsOneWidget);

    await tester.enterText(search, 'Liq');
    await tester.pumpAndSettle();
    expect(find.textContaining('Liquidación'), findsOneWidget);
    expect(find.textContaining('Temporada'), findsNothing);

    await tester.enterText(search, 'Li');
    await tester.pumpAndSettle();
    expect(find.textContaining('Liquidación'), findsOneWidget);
    expect(find.textContaining('Temporada'), findsOneWidget);
  });

  testWidgets('crear permite buscar y seleccionar productos identificables', (
    tester,
  ) async {
    _setLargeViewport(tester);
    final promotions = _RecordingPromotionRepository();
    await tester.pumpWidget(_app(promotions));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva promoción'));
    await tester.pumpAndSettle();

    expect(find.text('Nueva promoción'), findsOneWidget);
    await tester.enterText(_field('Nombre'), 'Oferta azul');
    await tester.enterText(_field('Descuento %'), '15');
    await tester.tap(find.text('Aplica a todos los productos'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.text('Productos específicos · 0 seleccionados'),
    );
    await tester.enterText(_field('Buscar productos'), 'SK');
    await tester.pumpAndSettle();
    expect(find.text('Taza azul'), findsOneWidget);
    expect(find.text('Organizador modular'), findsOneWidget);

    await tester.enterText(_field('Buscar productos'), 'SKU-BLUE');
    await tester.pumpAndSettle();
    expect(find.text('Taza azul'), findsOneWidget);
    expect(find.text('SKU-BLUE · Cerámica, 350 ml'), findsOneWidget);
    expect(find.text('Organizador modular'), findsNothing);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Productos específicos · 1 seleccionado'), findsOneWidget);
    await tester.enterText(
      _field('Condición para Taza azul'),
      'Mínimo de compra: 12 unidades',
    );
    await tester.ensureVisible(find.text('Crear promoción'));
    await tester.tap(find.text('Crear promoción'));
    await tester.pumpAndSettle();

    expect(promotions.savedPromotions, 1);
    expect(promotions.lastPromotion?.name, 'Oferta azul');
    expect(promotions.lastPromotion?.discountPercentage, 15);
    expect(promotions.lastPromotion?.appliesToAllProducts, isFalse);
    expect(promotions.lastProductIds, {'blue-id'});
    expect(promotions.lastProductConditions, {
      'blue-id': 'Mínimo de compra: 12 unidades',
    });
  });

  testWidgets('edición carga el alcance y persiste los cambios', (
    tester,
  ) async {
    _setLargeViewport(tester);
    final promotions = _RecordingPromotionRepository(
      initialPromotions: [
        BulkPromotion(
          id: 'promotion-1',
          name: 'Liquidación',
          discountPercentage: 10,
          conditionsText: 'Hasta agotar inventario',
          endDate: DateTime.now().add(const Duration(days: 30)),
          appliesToAllProducts: false,
          isActive: true,
          productIds: const {'blue-id'},
          productConditions: const {'blue-id': 'Mínimo de compra: 12 unidades'},
        ),
      ],
    );
    await tester.pumpWidget(
      _app(promotions, initialLocation: '/promotions/promotion-1/edit'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editar promoción'), findsOneWidget);
    await tester.enterText(_field('Nombre'), 'Temporada');
    await tester.ensureVisible(
      find.text('Productos específicos · 1 seleccionado'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Taza azul'), findsOneWidget);
    expect(find.text('Productos específicos · 1 seleccionado'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<TextField>(_field('Condición para Taza azul'))
          .controller
          ?.text,
      'Mínimo de compra: 12 unidades',
    );
    await tester.enterText(
      _field('Condición para Taza azul'),
      'Mínimo de compra: 6 unidades',
    );

    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(promotions.savedPromotions, 1);
    expect(promotions.lastPromotion?.id, 'promotion-1');
    expect(promotions.lastPromotion?.name, 'Temporada');
    expect(promotions.lastProductIds, {'blue-id'});
    expect(promotions.lastProductConditions, {
      'blue-id': 'Mínimo de compra: 6 unidades',
    });
  });

  testWidgets('datos inválidos no persisten y el formulario queda abierto', (
    tester,
  ) async {
    _setLargeViewport(tester);
    final promotions = _RecordingPromotionRepository();
    await tester.pumpWidget(
      _app(promotions, initialLocation: '/promotions/new'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_field('Nombre'), 'Oferta inválida');
    await tester.enterText(_field('Descuento %'), '150');
    await tester.tap(find.text('Crear promoción'));
    await tester.pumpAndSettle();

    expect(
      find.text('Indica un nombre y un descuento mayor que 0 y menor que 100.'),
      findsOneWidget,
    );
    expect(find.text('Nueva promoción'), findsOneWidget);
    expect(promotions.savedPromotions, 0);
  });

  testWidgets('avisa antes de salir si hay cambios sin guardar', (
    tester,
  ) async {
    _setLargeViewport(tester);
    final promotions = _RecordingPromotionRepository();
    await tester.pumpWidget(
      _app(promotions, initialLocation: '/promotions/new'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_field('Nombre'), 'Cambio temporal');
    await tester.pump();
    await tester.tap(find.byTooltip('Volver a promociones'));
    await tester.pumpAndSettle();
    expect(find.text('Salir sin guardar'), findsOneWidget);

    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva promoción'), findsOneWidget);
    expect(promotions.savedPromotions, 0);
  });
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Widget _app(
  _RecordingPromotionRepository promotions, {
  String initialLocation = '/promotions',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/promotions', builder: (_, _) => const PromotionPage()),
      GoRoute(
        path: '/promotions/new',
        builder: (_, _) => const PromotionFormPage(),
      ),
      GoRoute(
        path: '/promotions/:id/edit',
        builder: (_, state) =>
            PromotionFormPage(id: state.pathParameters['id']),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      productRepositoryProvider.overrideWithValue(_ProductCatalogStub()),
      promotionRepositoryProvider.overrideWithValue(promotions),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _ProductCatalogStub implements ProductRepository {
  @override
  Future<List<Product>> getProducts(ProductQuery query) async => [
    _product(
      id: 'blue-id',
      sku: 'SKU-BLUE',
      name: 'Taza azul',
      description: 'Cerámica, 350 ml',
    ),
    _product(
      id: 'organizer-id',
      sku: 'ORG-300',
      name: 'Organizador modular',
      description: 'Plástico reforzado',
    ),
  ];

  @override
  Future<List<Category>> getCategories() async => const [
    Category(id: 'category-1', name: 'General', isActive: true),
  ];

  @override
  Future<Product> createProduct(
    Product product, {
    required int initialStock,
  }) async => product;
  @override
  Future<Category> createCategory(String name) async =>
      Category(id: 'new', name: name, isActive: true);
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
  Future<Product> updateProduct(Product product) async => product;
  @override
  Future<void> saveCatalogOrder({
    required List<String> productIds,
    required List<String> categoryIds,
  }) async {}
}

class _RecordingPromotionRepository implements PromotionRepository {
  _RecordingPromotionRepository({this.initialPromotions = const []});

  final List<BulkPromotion> initialPromotions;
  int savedPromotions = 0;
  BulkPromotion? lastPromotion;
  Set<String> lastProductIds = const {};
  Set<String> lastCategoryIds = const {};
  Map<String, String> lastProductConditions = const {};

  @override
  Future<List<BulkPromotion>> getPromotions() async => initialPromotions;

  @override
  Future<BulkPromotion> createPromotion(
    BulkPromotion promotion, {
    required Set<String> productIds,
    Set<String> categoryIds = const {},
    Map<String, String> productConditions = const {},
  }) async {
    savedPromotions++;
    lastPromotion = promotion;
    lastProductIds = productIds;
    lastCategoryIds = categoryIds;
    lastProductConditions = productConditions;
    return promotion;
  }

  @override
  Future<BulkPromotion> updatePromotion(
    BulkPromotion promotion, {
    required Set<String> productIds,
    Set<String> categoryIds = const {},
    Map<String, String> productConditions = const {},
  }) async {
    savedPromotions++;
    lastPromotion = promotion;
    lastProductIds = productIds;
    lastCategoryIds = categoryIds;
    lastProductConditions = productConditions;
    return promotion;
  }

  @override
  Future<void> setActive(String id, {required bool isActive}) async {}
  @override
  Future<void> setProductCondition({
    required String promotionId,
    required String productId,
    required String conditionsText,
  }) async {}
}

Product _product({
  required String id,
  required String sku,
  required String name,
  required String description,
}) => Product(
  id: id,
  sku: sku,
  name: name,
  description: description,
  categoryId: 'category-1',
  unitPriceInCents: 1000,
  minimumOrderQuantity: 1,
  packagingPresentationId: 'presentation-1',
  cbmPerMoq: 0,
  factoryCostInCents: 500,
  currentStock: 5,
  reorderPoint: 1,
  isActive: true,
  createdAt: DateTime.utc(2026),
);
