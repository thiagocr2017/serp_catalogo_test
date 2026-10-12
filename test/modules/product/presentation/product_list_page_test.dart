import 'dart:async';

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

    await tester.tap(find.byTooltip('Acciones del producto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivar'));
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

    await tester.tap(find.byTooltip('Acciones del producto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.deactivatedIds, isEmpty);
    expect(find.text('Producto activo'), findsOneWidget);
  });

  testWidgets('reactivar desde tabla actualiza el filtro de inactivos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _ProductListRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inactivos').last);
    await tester.pumpAndSettle();
    expect(find.text('Producto inactivo'), findsOneWidget);
    expect(find.byTooltip('Acciones del producto'), findsOneWidget);

    await tester.tap(find.byTooltip('Acciones del producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Activar'));
    await tester.pumpAndSettle();

    expect(repository.activatedIds, ['inactive-id']);
    expect(repository.lastQuery?.isActive, isFalse);
    expect(find.text('Producto inactivo'), findsNothing);
  });

  testWidgets('reactivar desde cuadrícula actualiza el filtro de inactivos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _ProductListRepository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inactivos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cuadrícula'));
    await tester.pumpAndSettle();

    expect(find.text('Producto inactivo'), findsOneWidget);
    await tester.tap(find.byTooltip('Acciones del producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Activar'));
    await tester.pumpAndSettle();

    expect(repository.activatedIds, ['inactive-id']);
    expect(repository.lastQuery?.isActive, isFalse);
    expect(find.text('Producto inactivo'), findsNothing);
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
    await tester.tap(find.byTooltip('Acciones del producto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(repository.deactivatedIds, ['active-id']);
    expect(find.text('Producto activo'), findsNothing);
    expect(repository.lastQuery?.isActive, isTrue);
  });

  testWidgets(
    'desactivar al final de la tabla conserva la posición de scroll',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _ProductListRepository(
        activeProductCount: 35,
        refreshCompleter: Completer<void>(),
      );
      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      final lastAction = find.byTooltip('Acciones del producto').last;
      await tester.ensureVisible(lastAction);
      await tester.pumpAndSettle();
      final scrollState = Scrollable.of(tester.element(lastAction));
      expect(scrollState.position.pixels, greaterThan(0));

      await tester.tap(lastAction);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desactivar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
      await tester.pump();

      expect(find.text('Producto 34'), findsOneWidget);
      expect(scrollState.position.pixels, greaterThan(0));

      repository.refreshCompleter!.complete();
      await tester.pumpAndSettle();

      expect(find.text('Producto 34'), findsNothing);
      expect(scrollState.position.pixels, greaterThan(0));
    },
  );

  testWidgets('busca desde tres caracteres y limpia al bajar del umbral', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ProductListRepository(activeProductCount: 35);
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    final search = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Buscar por nombre, SKU o descripción',
    );
    await tester.enterText(search, 'ACT-34');
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.lastQuery!.searchTerm, isNull);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(repository.lastQuery!.searchTerm, 'ACT-34');
    expect(find.text('Producto 34'), findsOneWidget);

    await tester.enterText(search, 'AC');
    await tester.pumpAndSettle();
    expect(repository.lastQuery!.searchTerm, '');
    expect(find.text('Producto 34'), findsOneWidget);
  });

  testWidgets('conserva filas y anuncia progreso mientras busca', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final searchCompleter = Completer<void>();
    final repository = _ProductListRepository(
      refreshCompleter: searchCompleter,
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    final search = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Buscar por nombre, SKU o descripción',
    );
    await tester.enterText(search, 'ZZZ');
    await tester.pump(const Duration(milliseconds: 160));

    expect(find.text('Producto activo'), findsOneWidget);
    expect(find.bySemanticsLabel('Buscando productos'), findsOneWidget);

    searchCompleter.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('No hay productos que coincidan con los filtros.'),
      findsOneWidget,
    );
  });

  testWidgets('editar producto activo desde acciones de la tabla', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(_ProductListRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Acciones del producto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar active-id · list'), findsOneWidget);
  });

  testWidgets('editar producto inactivo desde acciones de la cuadrícula', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(_ProductListRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inactivos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cuadrícula'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Acciones del producto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar inactive-id · list'), findsOneWidget);
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
      GoRoute(
        path: '/products/:id/edit',
        builder: (_, state) => Scaffold(
          body: Text(
            'Editar ${state.pathParameters['id']} · '
            '${state.uri.queryParameters['returnTo']}',
          ),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [productRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _ProductListRepository implements ProductRepository {
  _ProductListRepository({int activeProductCount = 1, this.refreshCompleter})
    : _products = [
        for (var i = 0; i < activeProductCount; i++)
          _product(
            id: i == 0 ? 'active-id' : 'active-id-$i',
            sku: 'ACT-$i',
            name: i == 0 ? 'Producto activo' : 'Producto $i',
          ),
        _product(
          id: 'inactive-id',
          sku: 'INA-1',
          name: 'Producto inactivo',
          isActive: false,
        ),
      ];

  final List<Product> _products;
  final Completer<void>? refreshCompleter;
  var _getProductsCalls = 0;
  final deactivatedIds = <String>[];
  final activatedIds = <String>[];
  ProductQuery? lastQuery;

  @override
  Future<List<Product>> getProducts(ProductQuery query) async {
    lastQuery = query;
    _getProductsCalls++;
    if (_getProductsCalls > 1 && refreshCompleter != null) {
      await refreshCompleter!.future;
    }
    final searchTerm = query.searchTerm?.trim().toLowerCase() ?? '';
    return _products
        .where(
          (product) =>
              (query.isActive == null || product.isActive == query.isActive) &&
              (searchTerm.isEmpty ||
                  product.name.toLowerCase().contains(searchTerm) ||
                  product.sku.toLowerCase().contains(searchTerm) ||
                  product.description.toLowerCase().contains(searchTerm)),
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
  Future<Product> updateProduct(Product product) async {
    activatedIds.add(product.id);
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index >= 0) _products[index] = product;
    return product;
  }

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
