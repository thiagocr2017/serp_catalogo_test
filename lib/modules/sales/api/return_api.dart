import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sales_document_dtos.dart';

export 'sales_document_dtos.dart';

abstract interface class ReturnApi {
  Future<List<SalesReturnDto>> getReturns();
  Future<SalesReturnDto?> getReturnById(String id);
  Future<SalesReturnPreviewDto> previewReturn(String invoiceId) =>
      throw UnsupportedError('La previsualización no está disponible.');
  Future<SalesReturnDto> confirmReturn(ConfirmSalesReturnCommand command) =>
      throw UnsupportedError('La confirmación no está disponible.');
  Future<SalesReturnDto> createReturn({
    required String invoiceId,
    required String customerId,
    required String customerName,
    required String reason,
    required List<ReturnLineInput> lines,
  });
}

enum ReturnCondition { good, damaged }

enum ReturnFinancialResolution { refund, customerCredit }

class ConfirmSalesReturnCommand {
  const ConfirmSalesReturnCommand({
    required this.commandId,
    required this.invoiceId,
    required this.reason,
    required this.resolution,
    required this.lines,
  });

  final String commandId;
  final String invoiceId;
  final String reason;
  final ReturnFinancialResolution resolution;
  final List<ReturnLineInput> lines;
}

class SalesReturnPreviewDto {
  const SalesReturnPreviewDto({
    required this.invoiceId,
    required this.customerId,
    required this.customerName,
    required this.currencyCode,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.availableQuantities,
    required this.sellableLocations,
    required this.quarantineLocations,
  });

  final String invoiceId;
  final String customerId;
  final String customerName;
  final String currencyCode;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final Map<String, int> availableQuantities;
  final List<ReturnLocationDto> sellableLocations;
  final List<ReturnLocationDto> quarantineLocations;
}

class ReturnLocationDto {
  const ReturnLocationDto({
    required this.id,
    required this.warehouseId,
    required this.code,
    required this.name,
  });

  final String id;
  final String warehouseId;
  final String code;
  final String name;
}

final returnApiProvider = Provider<ReturnApi>(
  (ref) => throw StateError('ReturnApi must be overridden.'),
);

final returnsProvider = FutureProvider<List<SalesReturnDto>>(
  (ref) => ref.watch(returnApiProvider).getReturns(),
);

final returnByIdProvider = FutureProvider.family<SalesReturnDto?, String>(
  (ref, id) => ref.watch(returnApiProvider).getReturnById(id),
);
