import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/sales_order.dart';
import '../domain/repositories/order_repository.dart';

export '../domain/entities/sales_order.dart';

abstract interface class OrderApi {
  Future<List<SalesOrder>> getOrders();
  Future<SalesOrder?> getOrderById(String id);
  Future<SalesOrder> createOrder({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    String? agentId,
    String? quoteId,
    required List<OrderLineInput> lines,
    required String warehouseId,
    required String locationId,
  });
  Future<SalesOrder> cancelOrder(String id);
}

final orderApiProvider = Provider<OrderApi>(
  (ref) => throw StateError('OrderApi must be overridden.'),
);

final ordersProvider = FutureProvider<List<SalesOrder>>(
  (ref) => ref.watch(orderApiProvider).getOrders(),
);
