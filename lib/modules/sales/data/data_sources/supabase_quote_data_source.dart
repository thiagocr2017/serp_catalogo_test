import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/device/device_identity.dart';
import '../../domain/entities/sales_quote.dart';
import '../../domain/repositories/quote_repository.dart';

class SupabaseQuoteDataSource {
  const SupabaseQuoteDataSource(this._client, this._device);

  final SupabaseClient _client;
  final DeviceIdentity _device;

  Future<List<SalesQuote>> getQuotes() async {
    final rows = await _client
        .from('sales_quotes')
        .select('*, sales_quote_lines(*)')
        .order('created_at', ascending: false);
    return rows.map(_quote).toList();
  }

  Future<SalesQuote?> getQuoteById(String id) async {
    final row = await _client
        .from('sales_quotes')
        .select('*, sales_quote_lines(*)')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _quote(row);
  }

  Future<SalesQuote> createQuote({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_quote',
      params: {
        'p_customer_id': customerId,
        'p_customer_name': customerName,
        'p_currency_code': currencyCode,
        'p_exchange_rate': exchangeRate,
        'p_valid_until': validUntil?.toIso8601String().split('T').first,
        'p_notes': notes,
        'p_agent_id': agentId,
        'p_lines': [
          for (final l in lines)
            {
              'product_id': l.productId,
              'quantity': l.quantity,
              'unit_price': l.unitPrice,
              'discount_percent': l.discountPercent,
              'product_sku': l.productSku,
              'product_name': l.productName,
              'presentation_name': l.presentationName,
              'units_per_presentation': l.unitsPerPresentation,
            },
        ],
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _quote(row);
  }

  Future<SalesQuote> updateQuoteStatus(String id, QuoteStatus status) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'update_quote_status',
      params: {
        'p_quote_id': id,
        'p_status': switch (status) {
          QuoteStatus.draft => 'DRAFT',
          QuoteStatus.sent => 'SENT',
          QuoteStatus.accepted => 'ACCEPTED',
          QuoteStatus.rejected => 'REJECTED',
          QuoteStatus.expired => 'EXPIRED',
          QuoteStatus.converted => 'CONVERTED',
        },
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _quote(row);
  }

  Future<String> createDraftInvoiceFromQuote(String quoteId) async {
    return _client.rpc<String>(
      'create_draft_invoice_from_quote',
      params: {
        'p_command_id': const Uuid().v4(),
        'p_quote_id': quoteId,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
  }

  Future<SalesQuote> updateQuote({
    required String id,
    required String customerId,
    required String customerName,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'update_quote',
      params: {
        'p_quote_id': id,
        'p_customer_id': customerId,
        'p_customer_name': customerName,
        'p_valid_until': validUntil?.toIso8601String().split('T').first,
        'p_notes': notes,
        'p_agent_id': agentId,
        'p_lines': [
          for (final line in lines)
            {
              'product_id': line.productId,
              'quantity': line.quantity,
              'unit_price': line.unitPrice,
              'discount_percent': line.discountPercent,
              'product_sku': line.productSku,
              'product_name': line.productName,
              'presentation_name': line.presentationName,
              'units_per_presentation': line.unitsPerPresentation,
            },
        ],
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _quote(row);
  }

  SalesQuote _quote(Map<String, dynamic> row) => SalesQuote(
    id: row['id'] as String,
    quoteNumber: row['quote_number'] as String,
    customerName: row['customer_name'] as String,
    status: switch (row['status'] as String) {
      'DRAFT' => QuoteStatus.draft,
      'SENT' => QuoteStatus.sent,
      'ACCEPTED' => QuoteStatus.accepted,
      'REJECTED' => QuoteStatus.rejected,
      'EXPIRED' => QuoteStatus.expired,
      'CONVERTED' => QuoteStatus.converted,
      _ => QuoteStatus.draft,
    },
    totalAmount: (row['total_amount'] as num).toDouble(),
    currencyCode: row['currency_code'] as String,
    customerId: row['customer_id'] as String?,
    exchangeRate: (row['exchange_rate'] as num?)?.toDouble() ?? 1.0,
    validUntil: row['valid_until'] == null
        ? null
        : DateTime.parse(row['valid_until'] as String),
    notes: row['notes'] as String?,
    agentId: row['agent_id'] as String?,
    convertedInvoiceId: row['converted_invoice_id'] as String?,
    createdAt: row['created_at'] == null
        ? null
        : DateTime.parse(row['created_at'] as String),
    updatedAt: row['updated_at'] == null
        ? null
        : DateTime.parse(row['updated_at'] as String),
    lines: (row['sales_quote_lines'] as List<dynamic>? ?? const []).map((item) {
      final line = item as Map<String, dynamic>;
      return SalesQuoteLine(
        id: line['id'] as String,
        quoteId: line['quote_id'] as String,
        productId: line['product_id'] as String,
        quantity: line['quantity'] as int,
        unitPrice: (line['unit_price'] as num).toDouble(),
        totalPrice: (line['total_price'] as num).toDouble(),
        discountPercent: (line['discount_percent'] as num?)?.toDouble() ?? 0,
        productSku: line['product_sku'] as String?,
        productName: line['product_name'] as String?,
        presentationName: line['presentation_name'] as String?,
        unitsPerPresentation: line['units_per_presentation'] as int? ?? 1,
      );
    }).toList(),
  );
}
