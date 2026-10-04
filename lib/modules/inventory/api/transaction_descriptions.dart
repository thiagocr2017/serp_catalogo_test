import 'inventory_dtos.dart';

/// Lugar legible de un movimiento: "Bodega · Ubicación".
String transactionPlace(InventoryTransactionDto item) {
  final warehouse = item.warehouseName?.trim();
  final location = item.locationName?.trim();
  final hasWarehouse = warehouse != null && warehouse.isNotEmpty;
  final hasLocation = location != null && location.isNotEmpty;
  if (hasWarehouse && hasLocation) return '$warehouse · $location';
  if (hasWarehouse) return warehouse;
  if (hasLocation) return location;
  return 'Ubicación no disponible';
}

/// Pata complementaria de un traslado dentro del mismo documento.
/// Cada traslado genera dos movimientos (salida y entrada) con el mismo
/// documentId; esta función encuentra el otro para describir la ruta.
InventoryTransactionDto? transferCounterpart(
  InventoryTransactionDto item,
  List<InventoryTransactionDto> siblings,
) {
  if (item.documentId == null || item.documentId!.isEmpty) return null;
  final wanted = switch (item.reason) {
    InventoryReason.transferOut => InventoryReason.transferIn,
    InventoryReason.transferIn => InventoryReason.transferOut,
    _ => null,
  };
  if (wanted == null) return null;
  for (final sibling in siblings) {
    if (sibling.id != item.id &&
        sibling.documentId == item.documentId &&
        sibling.reason == wanted) {
      return sibling;
    }
  }
  return null;
}

/// Descripción humana de un movimiento. Cuando ambas patas de un traslado
/// están presentes muestra la ruta completa: "Traslado de A → B".
String describeInventoryTransaction(
  InventoryTransactionDto item, [
  List<InventoryTransactionDto> siblings = const [],
]) {
  switch (item.reason) {
    case InventoryReason.initialStock:
      return 'Stock inicial en ${transactionPlace(item)}';
    case InventoryReason.purchase:
      return 'Compra recibida en ${transactionPlace(item)}';
    case InventoryReason.sale:
      return 'Venta despachada desde ${transactionPlace(item)}';
    case InventoryReason.adjustment:
      return 'Ajuste en ${transactionPlace(item)}';
    case InventoryReason.returnItem:
      return 'Devolución en ${transactionPlace(item)}';
    case InventoryReason.reversal:
      return 'Reversión en ${transactionPlace(item)}';
    case InventoryReason.transferOut:
    case InventoryReason.transferIn:
      final counterpart = transferCounterpart(item, siblings);
      if (counterpart == null) {
        return item.reason == InventoryReason.transferOut
            ? 'Salida por traslado desde ${transactionPlace(item)}'
            : 'Entrada por traslado en ${transactionPlace(item)}';
      }
      final origin = item.reason == InventoryReason.transferOut
          ? item
          : counterpart;
      final destination = item.reason == InventoryReason.transferOut
          ? counterpart
          : item;
      final route =
          '${transactionPlace(origin)} → ${transactionPlace(destination)}';
      return item.reason == InventoryReason.transferOut
          ? 'Salida de $route'
          : 'Entrada en ${transactionPlace(destination)} '
                'desde ${transactionPlace(origin)}';
  }
}

/// Orden del historial: lo más reciente primero; dentro del mismo
/// documento la salida va antes que la entrada.
int compareInventoryHistory(InventoryTransactionDto a, InventoryTransactionDto b) {
  final byDate = b.createdAt.compareTo(a.createdAt);
  if (byDate != 0) return byDate;
  final byDocument = (a.documentId ?? '').compareTo(b.documentId ?? '');
  if (byDocument != 0) return byDocument;
  int leg(InventoryReason reason) => switch (reason) {
    InventoryReason.transferOut => 0,
    InventoryReason.transferIn => 1,
    _ => 2,
  };
  final byLeg = leg(a.reason).compareTo(leg(b.reason));
  if (byLeg != 0) return byLeg;
  return a.id.compareTo(b.id);
}
