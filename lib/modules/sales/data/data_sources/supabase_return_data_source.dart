import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/sales_return.dart';
import '../../domain/repositories/return_repository.dart';

class SupabaseReturnDataSource {
  const SupabaseReturnDataSource(this._client);

  final SupabaseClient _client;

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
  }) => throw UnsupportedError(
    'La confirmacion de devoluciones requiere el contrato atomico '
    'Sales/Inventory/Payments y no esta disponible.',
  );

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
  );
}
