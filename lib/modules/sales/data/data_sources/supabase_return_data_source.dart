import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/device_identity.dart';
import '../../api/return_api.dart';
import '../../domain/entities/sales_return.dart';
import '../../domain/repositories/return_repository.dart' as domain;

class SupabaseReturnDataSource {
  const SupabaseReturnDataSource(this._client, this._device);

  final SupabaseClient _client;
  final DeviceIdentity _device;

  Future<Map<String, dynamic>> previewReturn(String invoiceId) async =>
      await _client.rpc<Map<String, dynamic>>(
        'sales_preview_return',
        params: {'p_invoice_id': invoiceId},
      );

  Future<SalesReturn> confirmReturn(ConfirmSalesReturnCommand command) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'sales_confirm_return',
      params: {
        'p_command_id': command.commandId,
        'p_invoice_id': command.invoiceId,
        'p_reason': command.reason,
        'p_resolution': command.resolution.name == 'refund'
            ? 'REFUND'
            : 'CUSTOMER_CREDIT',
        'p_lines': [
          for (final line in command.lines)
            {
              'invoice_line_id': line.invoiceLineId,
              'product_id': line.productId,
              'quantity': line.quantity,
              'condition': line.condition,
              'condition_note': line.conditionNote,
              'location_id': line.locationId,
            },
        ],
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _return({...row, 'sales_return_lines': <dynamic>[]});
  }

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
    required List<domain.ReturnLineInput> lines,
  }) => throw UnsupportedError('Use confirmReturn con commandId y destinos.');

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
    lines: (row['sales_return_lines'] as List<dynamic>? ?? const [])
        .map((line) => _line(line as Map<String, dynamic>))
        .toList(),
    updatedAt: row['updated_at'] == null
        ? null
        : DateTime.parse(row['updated_at'] as String),
    confirmedAt: row['confirmed_at'] == null
        ? null
        : DateTime.parse(row['confirmed_at'] as String),
    debtReductionAmount:
        (row['debt_reduction_amount'] as num?)?.toDouble() ?? 0,
    financialResolution: row['financial_resolution'] as String?,
    financialResolutionAmount:
        (row['financial_resolution_amount'] as num?)?.toDouble() ?? 0,
  );

  SalesReturnLine _line(Map<String, dynamic> row) => SalesReturnLine(
    id: row['id'] as String,
    returnId: row['return_id'] as String,
    productId: row['product_id'] as String,
    invoiceLineId: row['invoice_line_id'] as String?,
    quantity: row['quantity'] as int,
    unitPrice: (row['unit_price'] as num).toDouble(),
    totalPrice: (row['total_price'] as num).toDouble(),
    productSku: row['product_sku'] as String?,
    productName: row['product_name'] as String?,
    condition: row['condition'] as String? ?? 'GOOD',
    conditionNote: row['condition_note'] as String?,
    inventoryLocationId: row['inventory_location_id'] as String?,
  );
}
