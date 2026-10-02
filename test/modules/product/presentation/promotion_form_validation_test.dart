import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/product/di/product_providers.dart';
import 'package:serp/modules/product/di/promotion_providers.dart';
import 'package:serp/modules/product/domain/entities/bulk_promotion.dart';
import 'package:serp/modules/product/domain/entities/category.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/domain/entities/product_query.dart';
import 'package:serp/modules/product/domain/repositories/product_repository.dart';
import 'package:serp/modules/product/domain/repositories/promotion_repository.dart';
import 'package:serp/modules/product/presentation/pages/promotion_page.dart';

void main() {
  testWidgets('promocion invalida mantiene formulario abierto y no guarda', (
    tester,
  ) async {
    final promotionRepository = _RecordingPromotionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(_ProductCatalogStub()),
          promotionRepositoryProvider.overrideWithValue(promotionRepository),
        ],
        child: const MaterialApp(home: PromotionPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva promoción'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Verano');
    await tester.enterText(
      find.widgetWithText(TextField, 'Descuento %'),
      '150',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
    await tester.pumpAndSettle();

    expect(
      find.text('El descuento debe ser mayor que 0 y máximo 100.'),
      findsOneWidget,
    );
    expect(find.text('Nueva promoción masiva'), findsOneWidget);
    expect(promotionRepository.savedPromotions, 0);
  });

  testWidgets('promocion valida se crea con alcance todos los productos', (
    tester,
  ) async {
    final promotionRepository = _RecordingPromotionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(_ProductCatalogStub()),
          promotionRepositoryProvider.overrideWithValue(promotionRepository),
        ],
        child: const MaterialApp(home: PromotionPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva promoción'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Verano');
    await tester.enterText(find.widgetWithText(TextField, 'Descuento %'), '15');
    await tester.enterText(
      find.widgetWithText(TextField, 'Condiciones'),
      'Compra mínima 6 unidades',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
    await tester.pumpAndSettle();

    expect(promotionRepository.savedPromotions, 1);
    expect(promotionRepository.lastPromotion?.name, 'Verano');
    expect(promotionRepository.lastPromotion?.discountPercentage, 15);
    expect(promotionRepository.lastPromotion?.appliesToAllProducts, isTrue);
    expect(promotionRepository.lastProductIds, isEmpty);
  });
}

class _ProductCatalogStub implements ProductRepository {
  @override
  Future<List<Product>> getProducts(ProductQuery query) async => [
    Product(
      id: 'product-1',
      sku: 'SKU-1',
      name: 'Producto',
      description: 'Descripcion',
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
  Future<Product> updateProduct(Product product) async => product;

  @override
  Future<void> saveCatalogOrder({
    required List<String> productIds,
    required List<String> categoryIds,
  }) async {}
}

class _RecordingPromotionRepository implements PromotionRepository {
  int savedPromotions = 0;
  BulkPromotion? lastPromotion;
  Set<String> lastProductIds = const {};

  @override
  Future<List<BulkPromotion>> getPromotions() async => const [];

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
