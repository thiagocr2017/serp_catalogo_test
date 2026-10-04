import 'package:flutter/foundation.dart';

import '../domain/entities/inventory_count.dart' show CountStatus;
import '../domain/entities/inventory_document.dart' show InventoryDocumentType;
import '../domain/entities/inventory_reservation.dart' show ReservationStatus;
import '../domain/entities/inventory_transaction.dart' show InventoryReason;

// Vocabulario publico del modulo de inventario: tipos de valor + DTO.
//
// `MODULE_SECURITY_CONTRACT.md` §3 permite exponer «identificadores opacos y
// tipos de valor compartidos» y prohibe exponer «entidades internas con campos
// que el consumidor no necesita».
//
// Los enums se **re-exportan con `show`** desde `domain/entities/`: son tipos de
// valor puros, sin comportamiento interno que ocultar, y duplicarlos obligaria
// a mapearlos en cada conversion. Se re-exportan solo ellos, nunca la entidad
// que los declara. Se hace asi y no declarandolos aqui para no invertir la
// dependencia: `domain/` no puede importar `api/`, porque este archivo usa
// Flutter y `MODULE_STRUCTURE.md` §4 exige que `domain` no dependa de el.
//
// Los DTO no incluyen `commandId`: la clave de idempotencia es un detalle de
// implementacion del comando, no un dato que el consumidor vaya a leer.

export '../domain/entities/inventory_count.dart' show CountStatus;
export '../domain/entities/inventory_document.dart' show InventoryDocumentType;
export '../domain/entities/inventory_reservation.dart' show ReservationStatus;
export '../domain/entities/inventory_transaction.dart' show InventoryReason;

// ---------------------------------------------------------------------------
// DTO
// ---------------------------------------------------------------------------

/// Movimiento del libro inmutable de inventario.
@immutable
class InventoryTransactionDto {
  const InventoryTransactionDto({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.reason,
    required this.warehouseId,
    required this.locationId,
    required this.createdAt,
    this.productSku,
    this.warehouseName,
    this.locationName,
    this.notes,
    this.reversalOfTransactionId,
    this.documentId,
    this.documentNumber,
  });

  /// Identificador opaco del movimiento.
  final String id;

  /// Identificador opaco del producto.
  final String productId;
  final String? productSku;

  /// Cantidad firmada: las salidas ya vienen negativas.
  final int quantity;
  final InventoryReason reason;

  /// Identificadores opacos de bodega y ubicacion.
  final String warehouseId;
  final String locationId;
  final String? warehouseName;
  final String? locationName;
  final String? notes;

  /// Identificador opaco del movimiento que este corrige, si lo hay.
  final String? reversalOfTransactionId;

  /// Identificador opaco del documento que origino el movimiento.
  final String? documentId;
  final String? documentNumber;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is InventoryTransactionDto &&
      other.id == id &&
      other.productId == productId &&
      other.productSku == productSku &&
      other.quantity == quantity &&
      other.reason == reason &&
      other.warehouseId == warehouseId &&
      other.locationId == locationId &&
      other.warehouseName == warehouseName &&
      other.locationName == locationName &&
      other.notes == notes &&
      other.reversalOfTransactionId == reversalOfTransactionId &&
      other.documentId == documentId &&
      other.documentNumber == documentNumber &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    productSku,
    quantity,
    reason,
    warehouseId,
    locationId,
    warehouseName,
    locationName,
    notes,
    reversalOfTransactionId,
    documentId,
    documentNumber,
    createdAt,
  );

  @override
  String toString() =>
      'InventoryTransactionDto(id: $id, sku: $productSku, '
      'quantity: $quantity, reason: ${reason.name})';
}

/// Saldo fisico de un producto en una ubicacion.
@immutable
class InventoryBalanceDto {
  const InventoryBalanceDto({
    required this.productId,
    required this.warehouseId,
    required this.locationId,
    required this.quantity,
    this.productSku,
    this.warehouseName,
    this.locationName,
  });

  final String productId;
  final String warehouseId;
  final String locationId;
  final int quantity;
  final String? productSku;
  final String? warehouseName;
  final String? locationName;

  @override
  bool operator ==(Object other) =>
      other is InventoryBalanceDto &&
      other.productId == productId &&
      other.warehouseId == warehouseId &&
      other.locationId == locationId &&
      other.quantity == quantity &&
      other.productSku == productSku &&
      other.warehouseName == warehouseName &&
      other.locationName == locationName;

  @override
  int get hashCode => Object.hash(
    productId,
    warehouseId,
    locationId,
    quantity,
    productSku,
    warehouseName,
    locationName,
  );

  @override
  String toString() =>
      'InventoryBalanceDto($productSku @ $locationName: '
      '$quantity)';
}

/// Ubicacion dentro de una bodega.
@immutable
class InventoryLocationDto {
  const InventoryLocationDto({
    required this.id,
    required this.warehouseId,
    required this.code,
    required this.name,
    required this.isDefault,
    required this.isActive,
  });

  final String id;
  final String warehouseId;
  final String code;
  final String name;
  final bool isDefault;
  final bool isActive;

  @override
  bool operator ==(Object other) =>
      other is InventoryLocationDto &&
      other.id == id &&
      other.warehouseId == warehouseId &&
      other.code == code &&
      other.name == name &&
      other.isDefault == isDefault &&
      other.isActive == isActive;

  @override
  int get hashCode =>
      Object.hash(id, warehouseId, code, name, isDefault, isActive);

  @override
  String toString() => 'InventoryLocationDto($code · $name)';
}

/// Bodega con sus ubicaciones.
@immutable
class WarehouseDto {
  const WarehouseDto({
    required this.id,
    required this.code,
    required this.name,
    required this.isDefault,
    required this.isActive,
    this.locations = const [],
  });

  final String id;
  final String code;
  final String name;
  final bool isDefault;
  final bool isActive;
  final List<InventoryLocationDto> locations;

  @override
  bool operator ==(Object other) =>
      other is WarehouseDto &&
      other.id == id &&
      other.code == code &&
      other.name == name &&
      other.isDefault == isDefault &&
      other.isActive == isActive &&
      listEquals(other.locations, locations);

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    isDefault,
    isActive,
    Object.hashAll(locations),
  );

  @override
  String toString() => 'WarehouseDto($code · $name)';
}

/// Linea de un documento de inventario.
@immutable
class InventoryDocumentLineDto {
  const InventoryDocumentLineDto({
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

  @override
  bool operator ==(Object other) =>
      other is InventoryDocumentLineDto &&
      other.id == id &&
      other.productId == productId &&
      other.quantity == quantity &&
      other.productSku == productSku &&
      other.productName == productName &&
      other.notes == notes;

  @override
  int get hashCode =>
      Object.hash(id, productId, quantity, productSku, productName, notes);

  @override
  String toString() => 'InventoryDocumentLineDto($productSku x $quantity)';
}

/// Documento de inventario con sus lineas.
@immutable
class InventoryDocumentDto {
  const InventoryDocumentDto({
    required this.id,
    required this.number,
    required this.type,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.originWarehouseName,
    this.originLocationName,
    this.destinationWarehouseName,
    this.destinationLocationName,
    this.externalReference,
    this.notes,
    this.lines = const [],
  });

  final String id;
  final String number;
  final InventoryDocumentType type;

  /// Estado textual del documento, por ejemplo `CONFIRMED` o `DRAFT`.
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? originWarehouseName;
  final String? originLocationName;
  final String? destinationWarehouseName;
  final String? destinationLocationName;
  final String? externalReference;
  final String? notes;
  final List<InventoryDocumentLineDto> lines;

  @override
  bool operator ==(Object other) =>
      other is InventoryDocumentDto &&
      other.id == id &&
      other.number == number &&
      other.type == type &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.originWarehouseName == originWarehouseName &&
      other.originLocationName == originLocationName &&
      other.destinationWarehouseName == destinationWarehouseName &&
      other.destinationLocationName == destinationLocationName &&
      other.externalReference == externalReference &&
      other.notes == notes &&
      listEquals(other.lines, lines);

  @override
  int get hashCode => Object.hash(
    id,
    number,
    type,
    status,
    createdAt,
    updatedAt,
    originWarehouseName,
    originLocationName,
    destinationWarehouseName,
    destinationLocationName,
    externalReference,
    notes,
    Object.hashAll(lines),
  );

  @override
  String toString() => 'InventoryDocumentDto($number, ${type.name}, $status)';
}

/// Reserva de stock para un pedido.
@immutable
class InventoryReservationDto {
  const InventoryReservationDto({
    required this.id,
    required this.productId,
    required this.locationId,
    required this.orderId,
    required this.quantity,
    required this.status,
    this.createdAt,
    this.releasedAt,
  });

  final String id;
  final String productId;
  final String locationId;

  /// Identificador opaco del pedido que reservo el stock.
  final String orderId;
  final int quantity;
  final ReservationStatus status;
  final DateTime? createdAt;
  final DateTime? releasedAt;

  @override
  bool operator ==(Object other) =>
      other is InventoryReservationDto &&
      other.id == id &&
      other.productId == productId &&
      other.locationId == locationId &&
      other.orderId == orderId &&
      other.quantity == quantity &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.releasedAt == releasedAt;

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    locationId,
    orderId,
    quantity,
    status,
    createdAt,
    releasedAt,
  );

  @override
  String toString() =>
      'InventoryReservationDto($id, ${status.name}, $quantity)';
}

/// Conteo fisico de inventario.
@immutable
class InventoryCountDto {
  const InventoryCountDto({
    required this.id,
    required this.warehouseId,
    required this.status,
    this.createdAt,
    this.confirmedAt,
  });

  final String id;
  final String warehouseId;
  final CountStatus status;
  final DateTime? createdAt;
  final DateTime? confirmedAt;

  @override
  bool operator ==(Object other) =>
      other is InventoryCountDto &&
      other.id == id &&
      other.warehouseId == warehouseId &&
      other.status == status &&
      other.createdAt == createdAt &&
      other.confirmedAt == confirmedAt;

  @override
  int get hashCode =>
      Object.hash(id, warehouseId, status, createdAt, confirmedAt);

  @override
  String toString() => 'InventoryCountDto($id, ${status.name})';
}

/// Accion de auditoria registrada por el sistema.
@immutable
class AuditEntryDto {
  const AuditEntryDto({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.operation,
    required this.createdAt,
    required this.fieldName,
    this.oldValue,
    this.newValue,
    this.actorName,
    this.deviceName,
    this.resourceLabel,
    this.resourcePath,
  });

  final String id;
  final String tableName;

  /// Identificador opaco del registro afectado.
  final String recordId;
  final String operation;
  final String fieldName;
  final String? oldValue;
  final String? newValue;
  final String? actorName;
  final String? deviceName;

  /// Etiqueta legible del recurso, por ejemplo el SKU.
  final String? resourceLabel;

  /// Ruta interna para navegar al recurso, si existe.
  final String? resourcePath;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is AuditEntryDto &&
      other.id == id &&
      other.tableName == tableName &&
      other.recordId == recordId &&
      other.operation == operation &&
      other.fieldName == fieldName &&
      other.oldValue == oldValue &&
      other.newValue == newValue &&
      other.actorName == actorName &&
      other.deviceName == deviceName &&
      other.resourceLabel == resourceLabel &&
      other.resourcePath == resourcePath &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    tableName,
    recordId,
    operation,
    fieldName,
    oldValue,
    newValue,
    actorName,
    deviceName,
    resourceLabel,
    resourcePath,
    createdAt,
  );

  @override
  String toString() =>
      'AuditEntryDto($tableName.$recordId, $operation, $fieldName)';
}
