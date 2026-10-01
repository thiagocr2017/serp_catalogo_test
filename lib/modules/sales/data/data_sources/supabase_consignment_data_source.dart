import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/device_identity.dart';
import '../../domain/entities/sales_consignment.dart';
import '../../domain/repositories/consignment_repository.dart';

class SupabaseConsignmentDataSource {
  const SupabaseConsignmentDataSource(this._client, this._device);

  final SupabaseClient _client;
  final DeviceIdentity _device;

  Future<List<SalesConsignment>> getConsignments() async {
    final rows = await _client
        .from('sales_consignments')
        .select('*, sales_consignment_lines(*)')
        .order('created_at', ascending: false);
    return rows.map(_consignment).toList();
  }

  Future<SalesConsignment?> getConsignmentById(String id) async {
    final row = await _client
        .from('sales_consignments')
        .select('*, sales_consignment_lines(*)')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _consignment(row);
  }

  Future<SalesConsignment> createConsignment({
    required String customerId,
    required String customerName,
    required String currencyCode,
    String? notes,
    String? agentId,
    required List<ConsignmentLineInput> lines,
    required String warehouseId,
    required String locationId,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_consignment',
      params: {
        'p_customer_id': customerId,
        'p_customer_name': customerName,
        'p_currency_code': currencyCode,
        'p_notes': notes,
        'p_agent_id': agentId,
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
        'p_warehouse_id': warehouseId,
        'p_location_id': locationId,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _consignment(row);
  }

  Future<SalesConsignment> registerReturn({
    required String consignmentId,
    required String productId,
    required int quantity,
  }) async {
    final row = await _client
        .from('sales_consignment_lines')
        .update({'returned_quantity': quantity})
        .eq('consignment_id', consignmentId)
        .eq('product_id', productId)
        .select()
        .single();
    return _consignment(row);
  }

  SalesConsignment _consignment(Map<String, dynamic> row) => SalesConsignment(
    id: row['id'] as String,
    consignmentNumber: row['consignment_number'] as String,
    customerName: row['customer_name'] as String,
    status: switch (row['status'] as String) {
      'DRAFT' => ConsignmentStatus.draft,
      'SENT' => ConsignmentStatus.sent,
      'PARTIAL_RETURN' => ConsignmentStatus.partialReturn,
      'RETURNED' => ConsignmentStatus.returned,
      'SETTLED' => ConsignmentStatus.settled,
      'CANCELLED' => ConsignmentStatus.cancelled,
      _ => ConsignmentStatus.draft,
    },
    totalAmount: (row['total_amount'] as num).toDouble(),
    currencyCode: row['currency_code'] as String,
    customerId: row['customer_id'] as String?,
    returnedAmount: (row['returned_amount'] as num?)?.toDouble() ?? 0,
    notes: row['notes'] as String?,
    agentId: row['agent_id'] as String?,
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
