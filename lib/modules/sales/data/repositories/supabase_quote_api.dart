import '../../api/quote_api.dart';
import '../../domain/repositories/quote_repository.dart' as domain;
import '../data_sources/supabase_quote_data_source.dart';
import '../mappers/sales_dto_mapper.dart';

class SupabaseQuoteApi implements QuoteApi {
  const SupabaseQuoteApi(this._source);

  final SupabaseQuoteDataSource _source;

  @override
  Future<List<SalesQuoteDto>> getQuotes() async {
    final quotes = await _source.getQuotes();
    return quotes.map((q) => q.toDto()).toList();
  }

  @override
  Future<SalesQuoteDto?> getQuoteById(String id) async {
    final quote = await _source.getQuoteById(id);
    return quote?.toDto();
  }

  @override
  Future<SalesQuoteDto> createQuote({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  }) async {
    final quote = await _source.createQuote(
      customerId: customerId,
      customerName: customerName,
      currencyCode: currencyCode,
      exchangeRate: exchangeRate,
      validUntil: validUntil,
      notes: notes,
      agentId: agentId,
      lines: [
        for (final l in lines)
          domain.QuoteLineInput(
            productId: l.productId,
            quantity: l.quantity,
            unitPrice: l.unitPrice,
            discountPercent: l.discountPercent,
            productSku: l.productSku,
            productName: l.productName,
          ),
      ],
    );
    return quote.toDto();
  }

  @override
  Future<SalesQuoteDto> updateQuoteStatus(String id, QuoteStatus status) async {
    final quote = await _source.updateQuoteStatus(id, status);
    return quote.toDto();
  }
}
