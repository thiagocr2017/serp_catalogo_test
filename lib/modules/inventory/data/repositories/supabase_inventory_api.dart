import '../../api/inventory_api.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../mappers/inventory_dto_mapper.dart';

/// Contrato publico de inventario: traduce las entidades de dominio a DTO.
///
/// Es la unica superficie que otros modulos consumen. El repositorio sigue
/// trabajando con entidades para el propio modulo; aqui se corta el acoplamiento,
/// de modo que un cambio interno de `InventoryTransaction` no sea un cambio de
/// contrato.
class SupabaseInventoryApi implements InventoryApi {
  const SupabaseInventoryApi(this._repository);

  final InventoryRepository _repository;

  @override
  Future<List<InventoryTransactionDto>> getTransactions({
    String? productId,
  }) async => [
    for (final t in await _repository.getTransactions(productId: productId))
      t.toDto(),
  ];

  @override
  Future<List<WarehouseDto>> getWarehouses({bool activeOnly = true}) async => [
    for (final w in await _repository.getWarehouses(activeOnly: activeOnly))
      w.toDto(),
  ];

  @override
  Future<List<InventoryBalanceDto>> getLocationBalances({
    String? productId,
  }) async => [
    for (final b in await _repository.getLocationBalances(productId: productId))
      b.toDto(),
  ];

  @override
  Future<List<InventoryDocumentDto>> getDocuments() async => [
    for (final d in await _repository.getDocuments()) d.toDto(),
  ];

  @override
  Future<InventoryDocumentDto?> getDocument(String id) async =>
      (await _repository.getDocument(id))?.toDto();

  @override
  Future<InventoryDocumentDto> createAndConfirmDocument(
    InventoryDocumentCommand command,
  ) async => (await _repository.createAndConfirmDocument(command)).toDto();

  @override
  Future<List<AuditEntryDto>> getAuditEntries({
    String? tableName,
    String? recordId,
  }) async => [
    for (final a in await _repository.getAuditEntries(
      tableName: tableName,
      recordId: recordId,
    ))
      a.toDto(),
  ];

  @override
  Future<InventoryReservationDto> reserveStock({
    required String productId,
    required String locationId,
    required String orderId,
    required int quantity,
  }) async => (await _repository.reserveStock(
    productId: productId,
    locationId: locationId,
    orderId: orderId,
    quantity: quantity,
  )).toDto();

  @override
  Future<void> releaseReservation(String reservationId) =>
      _repository.releaseReservation(reservationId);

  @override
  Future<void> consumeReservation(String reservationId) =>
      _repository.consumeReservation(reservationId);

  @override
  Future<InventoryCountDto> createCount(String warehouseId) async =>
      (await _repository.createCount(warehouseId)).toDto();

  @override
  Future<void> confirmCount(String countId) =>
      _repository.confirmCount(countId);

  @override
  Future<void> dispatchTransfer(String documentId) =>
      _repository.dispatchTransfer(documentId);

  @override
  Future<void> markTransferInTransit(String documentId) =>
      _repository.markTransferInTransit(documentId);

  @override
  Future<void> receiveTransfer(String documentId) =>
      _repository.receiveTransfer(documentId);

  @override
  Future<InventoryDocumentDto> confirmDocument(String documentId) async =>
      (await _repository.confirmDocument(documentId)).toDto();

  @override
  Future<void> dispatchDocument(String documentId) =>
      _repository.dispatchDocument(documentId);
}
