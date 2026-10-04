import '../../api/inventory_dtos.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/entities/inventory_balance.dart';
import '../../domain/entities/inventory_count.dart';
import '../../domain/entities/inventory_document.dart';
import '../../domain/entities/inventory_reservation.dart';
import '../../domain/entities/inventory_transaction.dart';
import '../../domain/entities/warehouse.dart';

/// Conversion entre las entidades de dominio y los DTO publicos.
///
/// Vive en `data/` porque es la capa que traduce representaciones externas.
/// `domain/` no conoce los DTO.
///
/// Los enums no se convierten: `api/` re-exporta exactamente esos tipos, asi
/// que se pasan tal cual.
extension InventoryTransactionMapper on InventoryTransaction {
  InventoryTransactionDto toDto() => InventoryTransactionDto(
    id: id,
    productId: productId,
    productSku: productSku,
    quantity: quantity,
    reason: reason,
    warehouseId: warehouseId,
    locationId: locationId,
    warehouseName: warehouseName,
    locationName: locationName,
    notes: notes,
    reversalOfTransactionId: reversalOfTransactionId,
    documentId: documentId,
    documentNumber: documentNumber,
    createdAt: createdAt,
  );
}

extension InventoryBalanceMapper on InventoryBalance {
  InventoryBalanceDto toDto() => InventoryBalanceDto(
    productId: productId,
    warehouseId: warehouseId,
    locationId: locationId,
    quantity: quantity,
    productSku: productSku,
    warehouseName: warehouseName,
    locationName: locationName,
  );
}

extension InventoryLocationMapper on InventoryLocation {
  InventoryLocationDto toDto() => InventoryLocationDto(
    id: id,
    warehouseId: warehouseId,
    code: code,
    name: name,
    isDefault: isDefault,
    isActive: isActive,
  );
}

extension WarehouseMapper on Warehouse {
  WarehouseDto toDto() =>
      WarehouseDto(id: id, code: code, name: name, isDefault: isDefault, isActive: isActive, locations: [for (final l in locations) l.toDto()]);
}

extension InventoryDocumentLineMapper on InventoryDocumentLine {
  InventoryDocumentLineDto toDto() => InventoryDocumentLineDto(
    id: id,
    productId: productId,
    quantity: quantity,
    productSku: productSku,
    productName: productName,
    notes: notes,
  );
}

extension InventoryDocumentMapper on InventoryDocument {
  InventoryDocumentDto toDto() => InventoryDocumentDto(
    id: id,
    number: number,
    type: type,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
    originWarehouseName: originWarehouseName,
    originLocationName: originLocationName,
    destinationWarehouseName: destinationWarehouseName,
    destinationLocationName: destinationLocationName,
    externalReference: externalReference,
    notes: notes,
    lines: [for (final l in lines) l.toDto()],
  );
}

extension InventoryReservationMapper on InventoryReservation {
  InventoryReservationDto toDto() => InventoryReservationDto(
    id: id,
    productId: productId,
    locationId: locationId,
    orderId: orderId,
    quantity: quantity,
    status: status,
    createdAt: createdAt,
    releasedAt: releasedAt,
  );
}

extension InventoryCountMapper on InventoryCount {
  InventoryCountDto toDto() => InventoryCountDto(
    id: id,
    warehouseId: warehouseId,
    status: status,
    createdAt: createdAt,
    confirmedAt: confirmedAt,
  );
}

extension AuditEntryMapper on AuditEntry {
  AuditEntryDto toDto() => AuditEntryDto(
    id: id,
    tableName: tableName,
    recordId: recordId,
    operation: operation,
    fieldName: fieldName,
    oldValue: oldValue,
    newValue: newValue,
    actorName: actorName,
    deviceName: deviceName,
    resourceLabel: resourceLabel,
    resourcePath: resourcePath,
    createdAt: createdAt,
  );
}
