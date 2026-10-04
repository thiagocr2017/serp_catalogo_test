import '../domain/entities/inventory_document.dart';

class InventoryDocumentCommand {
  const InventoryDocumentCommand({
    required this.commandId,
    required this.type,
    required this.lines,
    this.originWarehouseId,
    this.originLocationId,
    this.destinationWarehouseId,
    this.destinationLocationId,
    this.externalReference,
    this.notes,
    this.draft = false,
  });

  final String commandId;
  final InventoryDocumentType type;
  final List<InventoryDocumentLineCommand> lines;
  final String? originWarehouseId;
  final String? originLocationId;
  final String? destinationWarehouseId;
  final String? destinationLocationId;
  final String? externalReference;
  final String? notes;
  final bool draft;
}

class InventoryDocumentLineCommand {
  const InventoryDocumentLineCommand({
    required this.productId,
    required this.quantity,
    this.notes,
  });

  final String productId;
  final int quantity;
  final String? notes;
}
