import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sales_document_dtos.dart';

export 'sales_document_dtos.dart';

abstract interface class OrderApi {
  Future<List<SalesOrderDto>> getOrders();
  Future<SalesOrderDto?> getOrderById(String id);
  Future<SalesOrderDto> createOrder({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    String? agentId,
    String? quoteId,
    required List<OrderLineInput> lines,
    required String warehouseId,
    required String? locationId,
  });
  Future<SalesOrderDto> cancelOrder(String id);
}

final orderApiProvider = Provider<OrderApi>(
  (ref) => throw StateError('OrderApi must be overridden.'),
);

final ordersProvider = FutureProvider<List<SalesOrderDto>>(
  (ref) => ref.watch(orderApiProvider).getOrders(),
);

final orderByIdProvider = FutureProvider.family<SalesOrderDto?, String>(
  (ref, id) => ref.watch(orderApiProvider).getOrderById(id),
);
