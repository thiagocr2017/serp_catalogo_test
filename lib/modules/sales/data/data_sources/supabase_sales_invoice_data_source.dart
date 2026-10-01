import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/device/device_identity.dart';
import '../../domain/entities/sales_invoice.dart';
import '../../domain/repositories/sales_invoice_repository.dart';

class SupabaseSalesInvoiceDataSource {
  const SupabaseSalesInvoiceDataSource(this._client, this._device);

  final SupabaseClient _client;
  final DeviceIdentity _device;

  Future<List<SalesInvoice>> getInvoices() async {
    final rows = await _client
        .from('sales_invoices')
        .select('*, sales_invoice_lines(*)')
        .order('created_at', ascending: false);
    return rows.map(_invoice).toList();
  }

  Future<SalesInvoice?> getInvoiceById(String id) async {
    final row = await _client
        .from('sales_invoices')
        .select('*, sales_invoice_lines(*)')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _invoice(row);
  }

  Future<SalesInvoice> createInvoice({
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    required List<SalesInvoiceLineInput> lines,
    required String warehouseId,
    required String locationId,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_sale_invoice_with_dispatch',
      params: {
        'p_command_id': const Uuid().v4(),
        'p_customer_name': customerName,
        'p_currency_code': currencyCode,
        'p_exchange_rate': exchangeRate,
        'p_notes': notes,
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
    return _invoice(row);
  }

  Future<SalesInvoice> cancelInvoice(String id, {required String reason}) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'cancel_sale_invoice',
      params: {
        'p_invoice_id': id,
        'p_reason': reason,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _invoice(row);
  }

  SalesInvoice _invoice(Map<String, dynamic> row) {
    (row['sales_invoice_lines'] as List<dynamic>?)
            ?.map((l) => _line(l as Map<String, dynamic>))
            .toList();
    return SalesInvoice(
      id: row['id'] as String,
      invoiceNumber: row['invoice_number'] as String,
      customerName: row['customer_name'] as String,
      status: switch (row['status'] as String) {
        'DRAFT' => SalesInvoiceStatus.draft,
        'CONFIRMED' => SalesInvoiceStatus.confirmed,
        'CANCELLED' => SalesInvoiceStatus.cancelled,
        'PAID' => SalesInvoiceStatus.paid,
        _ => SalesInvoiceStatus.draft,
      },
      totalAmount: (row['total_amount'] as num).toDouble(),
      currencyCode: row['currency_code'] as String,
      customerId: row['customer_id'] as String?,
      exchangeRate: (row['exchange_rate'] as num?)?.toDouble() ?? 1.0,
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
      cancelledAt: row['cancelled_at'] == null
          ? null
          : DateTime.parse(row['cancelled_at'] as String),
    );
  }

  SalesInvoiceLine _line(Map<String, dynamic> row) => SalesInvoiceLine(
    id: row['id'] as String,
    invoiceId: row['invoice_id'] as String,
    productId: row['product_id'] as String,
    quantity: row['quantity'] as int,
    unitPrice: (row['unit_price'] as num).toDouble(),
    totalPrice: (row['total_price'] as num).toDouble(),
    discountPercent: (row['discount_percent'] as num?)?.toDouble() ?? 0,
    productSku: row['product_sku'] as String?,
    productName: row['product_name'] as String?,
  );
}
