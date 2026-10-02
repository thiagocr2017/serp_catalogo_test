import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/product/di/product_providers.dart';
import 'package:serp/modules/product/domain/entities/category.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/domain/entities/product_query.dart';
import 'package:serp/modules/product/domain/repositories/product_repository.dart';
import 'package:serp/modules/product/presentation/pages/category_page.dart';

void main() {
  testWidgets('categoria vacia exige correccion antes de guardar', (
    tester,
  ) async {
    final repository = _RecordingCategoryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [productRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: CategoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Escriba el nombre de la categoría.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(repository.createdCategories, 0);

    await tester.enterText(find.byType(TextField).last, 'Mayoristas');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.createdCategories, 1);
  });

  testWidgets('categoria existente carga, actualiza y elimina', (tester) async {
    final repository = _RecordingCategoryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [productRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: CategoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar categoría').first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Nombre'), findsOneWidget);
    expect(find.text('General'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Retail');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(repository.updatedCategoryId, 'category-1');
    expect(repository.updatedCategoryName, 'Retail');

    await tester.tap(find.byTooltip('Eliminar categoría').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(repository.deletedCategoryId, 'category-1');
  });
}

class _RecordingCategoryRepository implements ProductRepository {
  int createdCategories = 0;
  String? updatedCategoryId;
  String? updatedCategoryName;
  String? deletedCategoryId;

  @override
  Future<List<Category>> getCategories() async => const [
    Category(id: 'category-1', name: 'General', isActive: true),
    Category(id: 'category-2', name: 'Mayoristas', isActive: true),
  ];

  @override
  Future<Category> createCategory(String name) async {
    createdCategories++;
    return Category(id: 'category-new', name: name, isActive: true);
  }

  @override
  Future<Category> updateCategory(String id, String name) async {
    updatedCategoryId = id;
    updatedCategoryName = name;
    return Category(id: id, name: name, isActive: true);
  }

  @override
  Future<List<Product>> getProducts(ProductQuery query) async => const [];

  @override
  Future<Product> createProduct(
    Product product, {
    required int initialStock,
  }) async => product;

  @override
  Future<void> deleteCategory({
    required String categoryId,
    String? replacementCategoryId,
  }) async {
    deletedCategoryId = categoryId;
  }

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
