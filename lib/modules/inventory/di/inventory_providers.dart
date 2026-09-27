import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/audit_entry.dart';
import '../domain/entities/inventory_transaction.dart';
import '../domain/repositories/inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => throw StateError('InventoryRepository must be overridden.'),
);
final inventoryTransactionsProvider =
    FutureProvider<List<InventoryTransaction>>(
      (ref) => ref.watch(inventoryRepositoryProvider).getTransactions(),
    );
final auditEntriesProvider = FutureProvider<List<AuditEntry>>(
  (ref) => ref.watch(inventoryRepositoryProvider).getAuditEntries(),
);
final productTransactionsProvider =
    FutureProvider.family<List<InventoryTransaction>, String>(
      (ref, productId) => ref
          .watch(inventoryRepositoryProvider)
          .getTransactions(productId: productId),
    );
final productAuditProvider = FutureProvider.family<List<AuditEntry>, String>(
  (ref, productId) => ref
      .watch(inventoryRepositoryProvider)
      .getAuditEntries(tableName: 'products', recordId: productId),
);
