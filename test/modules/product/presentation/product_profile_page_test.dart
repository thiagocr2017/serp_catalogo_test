import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/inventory/api/inventory_api.dart';
import 'package:serp/modules/product/di/product_providers.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/domain/entities/category.dart';
import 'package:serp/modules/product/domain/entities/product_query.dart';
import 'package:serp/modules/product/domain/repositories/product_repository.dart';
import 'package:serp/modules/product/presentation/pages/product_profile_page.dart';

void main() {
  testWidgets('long SKU and barcode fit a narrow profile and remain copyable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const sku = 'SERP-EXTREMADAMENTE-LARGO-0123456789';
    const barcode = '75012345678901234567890123456789';
    final clipboard = <String, dynamic>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.addAll(Map<String, dynamic>.from(call.arguments as Map));
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(_ProductRepository()),
          inventoryApiProvider.overrideWithValue(_InventoryApi()),
        ],
        child: const MaterialApp(
          home: ProductProfilePage(productId: 'product-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Copiar SKU'), findsOneWidget);
    expect(find.byTooltip('Copiar Código de barras'), findsOneWidget);
    await tester.tap(find.byTooltip('Copiar SKU'));
    await tester.pump();
    expect(clipboard['text'], sku);
    await tester.tap(find.byTooltip('Copiar Código de barras'));
    await tester.pump();
    expect(clipboard['text'], barcode);
    expect(tester.takeException(), isNull);
  });
}

class _ProductRepository implements ProductRepository {
  @override
  Future<Product?> getProductById(String id) async => Product(
    id: id,
    sku: 'SERP-EXTREMADAMENTE-LARGO-0123456789',
    barcode: '75012345678901234567890123456789',
    name: 'Producto de prueba',
    description: 'Descripción',
    categoryId: 'category-1',
    unitPriceInCents: 1000,
    minimumOrderQuantity: 1,
    packagingPresentationId: 'unit-1',
    packagingPresentationName: 'Unidad',
    cbmPerMoq: 0.1,
    factoryCostInCents: 500,
    currentStock: 4,
    reorderPoint: 1,
    isActive: true,
    createdAt: DateTime(2026),
  );

  @override
  Future<List<Product>> getProducts(ProductQuery query) async => const [];
  @override
  Future<Product> createProduct(Product product, {required int initialStock}) =>
      throw UnimplementedError();
  @override
  Future<List<Category>> getCategories() async => const [];
  @override
  Future<Category> createCategory(String name) => throw UnimplementedError();
  @override
  Future<Category> updateCategory(String id, String name) =>
      throw UnimplementedError();
  @override
  Future<void> deleteCategory({
    required String categoryId,
    String? replacementCategoryId,
  }) => throw UnimplementedError();
  @override
  Future<Product> updateProduct(Product product) => throw UnimplementedError();
  @override
  Future<void> deactivateProduct(String id) => throw UnimplementedError();
  @override
  Future<void> saveCatalogOrder({
    required List<String> productIds,
    required List<String> categoryIds,
  }) => throw UnimplementedError();
}

class _InventoryApi implements InventoryApi {
  @override
  Future<List<InventoryTransactionDto>> getTransactions({
    String? productId,
  }) async => const [];
  @override
  Future<List<WarehouseDto>> getWarehouses({bool activeOnly = true}) async =>
      const [];
  @override
  Future<List<InventoryBalanceDto>> getLocationBalances({
    String? productId,
  }) async => const [];
  @override
  Future<List<InventoryDocumentDto>> getDocuments() async => const [];
  @override
  Future<InventoryDocumentDto?> getDocument(String id) async => null;
  @override
  Future<InventoryDocumentDto> createAndConfirmDocument(
    InventoryDocumentCommand command,
  ) => throw UnimplementedError();
  @override
  Future<List<AuditEntryDto>> getAuditEntries({
    String? tableName,
    String? recordId,
  }) async => const [];
  @override
  Future<InventoryReservationDto> reserveStock({
    required String productId,
    required String locationId,
    required String orderId,
    required int quantity,
  }) => throw UnimplementedError();
  @override
  Future<void> releaseReservation(String reservationId) =>
      throw UnimplementedError();
  @override
  Future<void> consumeReservation(String reservationId) =>
      throw UnimplementedError();
  @override
  Future<InventoryCountDto> createCount(String warehouseId) =>
      throw UnimplementedError();
  @override
  Future<void> confirmCount(String countId) => throw UnimplementedError();
  @override
  Future<void> dispatchTransfer(String documentId) =>
      throw UnimplementedError();
  @override
  Future<void> markTransferInTransit(String documentId) =>
      throw UnimplementedError();
  @override
  Future<void> receiveTransfer(String documentId) => throw UnimplementedError();
  @override
  Future<InventoryDocumentDto> confirmDocument(String documentId) =>
      throw UnimplementedError();
  @override
  Future<void> dispatchDocument(String documentId) =>
      throw UnimplementedError();
}
