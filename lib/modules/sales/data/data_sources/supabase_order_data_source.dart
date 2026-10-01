import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/device_identity.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/repositories/order_repository.dart';

class SupabaseOrderDataSource {
  const SupabaseOrderDataSource(this._client, this._device);

  final SupabaseClient _client;
  final DeviceIdentity _device;

  Future<List<SalesOrder>> getOrders() async {
    final rows = await _client
        .from('sales_orders')
        .select('*, sales_order_lines(*)')
        .order('created_at', ascending: false);
    return rows.map(_order).toList();
  }

  Future<SalesOrder?> getOrderById(String id) async {
    final row = await _client
        .from('sales_orders')
        .select('*, sales_order_lines(*)')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _order(row);
  }

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
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_order_with_reservation',
      params: {
        'p_customer_id': customerId,
        'p_customer_name': customerName,
        'p_currency_code': currencyCode,
        'p_exchange_rate': exchangeRate,
        'p_notes': notes,
        'p_agent_id': agentId,
        'p_quote_id': quoteId,
        'p_lines': [
          for (final l in lines)
            {
              'product_id': l.productId,
              'quantity': l.quantity,
              'unit_price': l.unitPrice,
              'discount_percent': l.discountPercent,
              'product_sku': l.productSku,
              'product_name': l.productName,
            },
        ],
        'p_warehouse_id': warehouseId,
        'p_location_id': locationId,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _order(row);
  }

  Future<SalesOrder> cancelOrder(String id) async {
    final row = await _client
        .from('sales_orders')
        .update({
          'status': 'CANCELLED',
          'cancelled_at': DateTime.now().toIso8601String(),
          'updated_by': _device.actorName,
          'updated_device_name': _device.name,
          'updated_device_identifier': _device.identifier,
        })
        .eq('id', id)
        .select()
        .single();
    return _order(row);
  }

  SalesOrder _order(Map<String, dynamic> row) => SalesOrder(
    id: row['id'] as String,
    orderNumber: row['order_number'] as String,
    customerName: row['customer_name'] as String,
    status: switch (row['status'] as String) {
      'DRAFT' => OrderStatus.draft,
      'CONFIRMED' => OrderStatus.confirmed,
      'RESERVED' => OrderStatus.reserved,
      'DISPATCHED' => OrderStatus.dispatched,
      'DELIVERED' => OrderStatus.delivered,
      'CANCELLED' => OrderStatus.cancelled,
      _ => OrderStatus.draft,
    },
    totalAmount: (row['total_amount'] as num).toDouble(),
    currencyCode: row['currency_code'] as String,
    customerId: row['customer_id'] as String?,
    exchangeRate: (row['exchange_rate'] as num?)?.toDouble() ?? 1.0,
    notes: row['notes'] as String?,
    agentId: row['agent_id'] as String?,
    quoteId: row['quote_id'] as String?,
    inventoryDocumentId: row['inventory_document_id'] as String?,
    createdAt: row['created_at'] == null
        ? null
        : DateTime.parse(row['created_at'] as String),
    updatedAt: row['updated_at'] == null
        ? null
        : DateTime.parse(row['updated_at'] as String),
    confirmedAt: row['confirmed_at'] == null
        ? null
        : DateTime.parse(row['confirmed_at'] as String),
    cancelledAt: row['cancelled_at'] == null
        ? null
        : DateTime.parse(row['cancelled_at'] as String),
  );
}
