import '../../api/order_api.dart';
import '../../domain/repositories/order_repository.dart' as domain;
import '../data_sources/supabase_order_data_source.dart';
import '../mappers/sales_dto_mapper.dart';

class SupabaseOrderApi implements OrderApi {
  const SupabaseOrderApi(this._source);

  final SupabaseOrderDataSource _source;

  @override
  Future<List<SalesOrderDto>> getOrders() async {
    final orders = await _source.getOrders();
    return orders.map((o) => o.toDto()).toList();
  }

  @override
  Future<SalesOrderDto?> getOrderById(String id) async {
    final order = await _source.getOrderById(id);
    return order?.toDto();
  }

  @override
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
  }) async {
    final order = await _source.createOrder(
      customerId: customerId,
      customerName: customerName,
      currencyCode: currencyCode,
      exchangeRate: exchangeRate,
      notes: notes,
      agentId: agentId,
      quoteId: quoteId,
      lines: [
        for (final l in lines)
          domain.OrderLineInput(
            productId: l.productId,
            quantity: l.quantity,
            unitPrice: l.unitPrice,
            discountPercent: l.discountPercent,
            productSku: l.productSku,
            productName: l.productName,
          ),
      ],
      warehouseId: warehouseId,
      locationId: locationId,
    );
    return order.toDto();
  }

  @override
  Future<SalesOrderDto> cancelOrder(String id) async {
    final order = await _source.cancelOrder(id);
    return order.toDto();
  }
}
