import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/inventory_api.dart';
import '../domain/repositories/inventory_repository.dart';

/// Repositorio de dominio. Solo lo usan el propio modulo y `main.dart` como
/// raiz de composicion. Trabaja con entidades.
final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => throw StateError('InventoryRepository must be overridden.'),
);

/// Los read-models de presentacion se construyen sobre la **API publica**, que
/// devuelve DTO. Asi `presentation` nunca ve entidades de dominio y un cambio
/// interno de `InventoryTransaction` no rompe la interfaz.
final inventoryTransactionsProvider =
    FutureProvider<List<InventoryTransactionDto>>((ref) {
      ref.watch(inventoryDataRevisionProvider);
      return ref.watch(inventoryApiProvider).getTransactions();
    });
final warehousesProvider = FutureProvider<List<WarehouseDto>>((ref) {
  ref.watch(inventoryDataRevisionProvider);
  return ref.watch(inventoryApiProvider).getWarehouses();
});
final auditEntriesProvider = FutureProvider<List<AuditEntryDto>>((ref) {
  ref.watch(inventoryDataRevisionProvider);
  return ref.watch(inventoryApiProvider).getAuditEntries();
});
final inventoryProductTransactionsProvider =
    FutureProvider.family<List<InventoryTransactionDto>, String>((
      ref,
      productId,
    ) {
      ref.watch(inventoryDataRevisionProvider);
      return ref.watch(inventoryApiProvider).getTransactions(
        productId: productId,
      );
    });
final inventoryProductAuditProvider =
    FutureProvider.family<List<AuditEntryDto>, String>((ref, productId) {
      ref.watch(inventoryDataRevisionProvider);
      return ref.watch(inventoryApiProvider).getAuditEntries(
        tableName: 'products',
        recordId: productId,
      );
    });

final inventoryDocumentsProvider = FutureProvider<List<InventoryDocumentDto>>(
  (ref) => ref.watch(inventoryApiProvider).getDocuments(),
);
