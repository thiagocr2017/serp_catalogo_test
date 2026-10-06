import '../../domain/entities/sales_quote.dart';
import '../../domain/repositories/quote_repository.dart';
import '../data_sources/supabase_quote_data_source.dart';

class SupabaseQuoteRepository implements QuoteRepository {
  const SupabaseQuoteRepository(this._source);

  final SupabaseQuoteDataSource _source;

  @override
  Future<List<SalesQuote>> getQuotes() => _source.getQuotes();

  @override
  Future<SalesQuote?> getQuoteById(String id) => _source.getQuoteById(id);

  @override
  Future<SalesQuote> createQuote({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  }) => _source.createQuote(
    customerId: customerId,
    customerName: customerName,
    currencyCode: currencyCode,
    exchangeRate: exchangeRate,
    validUntil: validUntil,
    notes: notes,
    agentId: agentId,
    lines: lines,
  );

  @override
  Future<SalesQuote> updateQuoteStatus(String id, QuoteStatus status) =>
      _source.updateQuoteStatus(id, status);

  @override
  Future<SalesQuote> updateQuote({
    required String id,
    required String customerId,
    required String customerName,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  }) => _source.updateQuote(
    id: id,
    customerId: customerId,
    customerName: customerName,
    validUntil: validUntil,
    notes: notes,
    agentId: agentId,
    lines: lines,
  );
}
