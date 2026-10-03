import '../../api/order_api.dart';
import '../../domain/repositories/order_repository.dart';
import '../data_sources/supabase_order_data_source.dart';

class SupabaseOrderRepository implements OrderRepository, OrderApi {
  const SupabaseOrderRepository(this._source);

  final SupabaseOrderDataSource _source;

  @override
  Future<List<SalesOrder>> getOrders() => _source.getOrders();

  @override
  Future<SalesOrder?> getOrderById(String id) => _source.getOrderById(id);

  @override
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
  }) => _source.createOrder(
    customerId: customerId,
    customerName: customerName,
    currencyCode: currencyCode,
    exchangeRate: exchangeRate,
    notes: notes,
    agentId: agentId,
    quoteId: quoteId,
    lines: lines,
    warehouseId: warehouseId,
    locationId: locationId,
  );

  @override
  Future<SalesOrder> cancelOrder(String id) => _source.cancelOrder(id);
}
