import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/product/di/product_providers.dart';
import 'package:serp/modules/product/domain/entities/category.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/domain/entities/product_query.dart';
import 'package:serp/modules/product/domain/repositories/product_repository.dart';
import 'package:serp/modules/product/presentation/pages/product_list_page.dart';

void main() {
  testWidgets('desactivar desde la lista requiere confirmación y actualiza', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _ProductListRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Producto activo'), findsOneWidget);
    expect(find.text('Producto inactivo'), findsNothing);
    expect(repository.lastQuery?.isActive, isTrue);

    await tester.tap(find.byTooltip('Desactivar producto').first);
    await tester.pumpAndSettle();
    expect(find.text('Desactivar producto'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(repository.deactivatedIds, ['active-id']);
    expect(find.text('Producto activo'), findsNothing);
    expect(find.text('Producto inactivo'), findsNothing);
    expect(repository.lastQuery?.isActive, isTrue);
  });

  testWidgets('cancelar desactivación no cambia el producto', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _ProductListRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Desactivar producto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.deactivatedIds, isEmpty);
    expect(find.text('Producto activo'), findsOneWidget);
  });

  testWidgets('desactivar desde cuadrícula actualiza el filtro activo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _ProductListRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cuadrícula'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Desactivar producto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(repository.deactivatedIds, ['active-id']);
    expect(find.text('Producto activo'), findsNothing);
    expect(repository.lastQuery?.isActive, isTrue);
  });
}

Widget _app(_ProductListRepository repository) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ProductListPage()),
      GoRoute(
        path: '/products/new',
        builder: (_, _) => const Scaffold(body: Text('Nuevo producto')),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Producto ${state.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [productRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _ProductListRepository implements ProductRepository {
  final List<Product> _products = [
    _product(id: 'active-id', sku: 'ACT-1', name: 'Producto activo'),
    _product(
      id: 'inactive-id',
      sku: 'INA-1',
      name: 'Producto inactivo',
      isActive: false,
    ),
  ];
  final deactivatedIds = <String>[];
  ProductQuery? lastQuery;

  @override
  Future<List<Product>> getProducts(ProductQuery query) async {
    lastQuery = query;
    return _products
        .where(
          (product) =>
              query.isActive == null || product.isActive == query.isActive,
        )
        .toList();
  }

  @override
  Future<List<Category>> getCategories() async => const [
    Category(id: 'category-id', name: 'General', isActive: true),
  ];

  @override
  Future<void> deactivateProduct(String id) async {
    deactivatedIds.add(id);
    final index = _products.indexWhere((product) => product.id == id);
    _products[index] = _product(
      id: _products[index].id,
      sku: _products[index].sku,
      name: _products[index].name,
      isActive: false,
    );
  }

  @override
  Future<Product?> getProductById(String id) async => null;

  @override
  Future<Product> createProduct(
    Product product, {
    required int initialStock,
  }) async => product;

  @override
  Future<Category> createCategory(String name) async =>
      Category(id: 'new-category', name: name, isActive: true);

  @override
  Future<Category> updateCategory(String id, String name) async =>
      Category(id: id, name: name, isActive: true);

  @override
  Future<void> deleteCategory({
    required String categoryId,
    String? replacementCategoryId,
  }) async {}

  @override
  Future<Product> updateProduct(Product product) async => product;

  @override
  Future<void> saveCatalogOrder({
    required List<String> productIds,
    required List<String> categoryIds,
  }) async {}
}

Product _product({
  required String id,
  required String sku,
  required String name,
  bool isActive = true,
}) => Product(
  id: id,
  sku: sku,
  name: name,
  description: '',
  categoryId: 'category-id',
  unitPriceInCents: 1000,
  minimumOrderQuantity: 1,
  packagingPresentationId: 'presentation-id',
  cbmPerMoq: 0,
  factoryCostInCents: 500,
  currentStock: 5,
  reorderPoint: 1,
  isActive: isActive,
  createdAt: DateTime.utc(2026),
);
