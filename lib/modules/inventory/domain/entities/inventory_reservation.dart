enum ReservationStatus { pending, released, consumed }

class InventoryReservation {
  const InventoryReservation({
    required this.id,
    required this.productId,
    required this.locationId,
    required this.orderId,
    required this.quantity,
    required this.status,
    required this.commandId,
    this.createdAt,
    this.releasedAt,
  });

  final String id;
  final String productId;
  final String locationId;
  final String orderId;
  final int quantity;
  final ReservationStatus status;
  final String commandId;
  final DateTime? createdAt;
  final DateTime? releasedAt;
}
