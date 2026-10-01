import 'package:supabase_flutter/supabase_flutter.dart';

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
    final row = await _client
        .from('sales_quotes')
        .update({'status': switch (status) {
          QuoteStatus.draft => 'DRAFT',
          QuoteStatus.sent => 'SENT',
          QuoteStatus.accepted => 'ACCEPTED',
          QuoteStatus.rejected => 'REJECTED',
          QuoteStatus.expired => 'EXPIRED',
          QuoteStatus.converted => 'CONVERTED',
        }})
        .eq('id', id)
        .select()
        .single();
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
    createdAt: row['created_at'] == null
        ? null
        : DateTime.parse(row['created_at'] as String),
    updatedAt: row['updated_at'] == null
        ? null
        : DateTime.parse(row['updated_at'] as String),
  );
}
