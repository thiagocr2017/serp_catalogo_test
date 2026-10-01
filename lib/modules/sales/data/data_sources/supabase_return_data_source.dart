import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/device_identity.dart';
import '../../domain/entities/sales_return.dart';
import '../../domain/repositories/return_repository.dart';

class SupabaseReturnDataSource {
  const SupabaseReturnDataSource(this._client, this._device);

  final SupabaseClient _client;
  final DeviceIdentity _device;

  Future<List<SalesReturn>> getReturns() async {
    final rows = await _client
        .from('sales_returns')
        .select('*, sales_return_lines(*)')
        .order('created_at', ascending: false);
    return rows.map(_return).toList();
  }

  Future<SalesReturn?> getReturnById(String id) async {
    final row = await _client
        .from('sales_returns')
        .select('*, sales_return_lines(*)')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _return(row);
  }

  Future<SalesReturn> createReturn({
    required String invoiceId,
    required String customerId,
    required String customerName,
    required String reason,
    required List<ReturnLineInput> lines,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_return',
      params: {
        'p_invoice_id': invoiceId,
        'p_customer_id': customerId,
        'p_customer_name': customerName,
        'p_reason': reason,
        'p_lines': [
          for (final l in lines)
            {
              'product_id': l.productId,
              'quantity': l.quantity,
              'unit_price': l.unitPrice,
              'product_sku': l.productSku,
              'product_name': l.productName,
            },
        ],
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _return(row);
  }

  SalesReturn _return(Map<String, dynamic> row) => SalesReturn(
    id: row['id'] as String,
    returnNumber: row['return_number'] as String,
    customerName: row['customer_name'] as String,
    status: switch (row['status'] as String) {
      'DRAFT' => ReturnStatus.draft,
      'CONFIRMED' => ReturnStatus.confirmed,
      'CANCELLED' => ReturnStatus.cancelled,
      _ => ReturnStatus.draft,
    },
    totalAmount: (row['total_amount'] as num).toDouble(),
    currencyCode: row['currency_code'] as String,
    reason: row['reason'] as String,
    invoiceId: row['invoice_id'] as String?,
    customerId: row['customer_id'] as String?,
    notes: row['notes'] as String?,
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
  );
}
