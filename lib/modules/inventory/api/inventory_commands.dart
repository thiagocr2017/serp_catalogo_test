import '../domain/entities/inventory_transaction.dart';

class InventoryTransactionCommand {
  const InventoryTransactionCommand({
    required this.commandId,
    required this.productId,
    required this.locationId,
    required this.quantity,
    required this.reason,
    this.notes,
  });

  final String commandId;
  final String productId;
  final String locationId;
  final int quantity;
  final InventoryReason reason;
  final String? notes;
}

class InventoryReversalCommand {
  const InventoryReversalCommand({
    required this.commandId,
    required this.originalTransactionId,
    required this.notes,
  });

  final String commandId;
  final String originalTransactionId;
  final String notes;
}
