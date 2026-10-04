enum InventoryDocumentType {
  opening,
  adjustment,
  transfer,
  purchaseReceipt,
  saleDispatch,
  customerReturn,
  supplierReturn,
  consignment,
}

class InventoryDocument {
  const InventoryDocument({
    required this.id,
    required this.number,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.lines,
    this.originWarehouseName,
    this.originLocationName,
    this.destinationWarehouseName,
    this.destinationLocationName,
    this.externalReference,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String number;
  final InventoryDocumentType type;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? originWarehouseName;
  final String? originLocationName;
  final String? destinationWarehouseName;
  final String? destinationLocationName;
  final String? externalReference;
  final String? notes;
  final List<InventoryDocumentLine> lines;
}

class InventoryDocumentLine {
  const InventoryDocumentLine({
    required this.id,
    required this.productId,
    required this.quantity,
    this.productSku,
    this.productName,
    this.notes,
  });

  final String id;
  final String productId;
  final int quantity;
  final String? productSku;
  final String? productName;
  final String? notes;
}
