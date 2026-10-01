import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/sales_quote.dart';
import '../domain/repositories/quote_repository.dart';

export '../domain/entities/sales_quote.dart';
export '../domain/repositories/quote_repository.dart';

abstract interface class QuoteApi {
  Future<List<SalesQuote>> getQuotes();
  Future<SalesQuote?> getQuoteById(String id);
  Future<SalesQuote> createQuote({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  });
  Future<SalesQuote> updateQuoteStatus(String id, QuoteStatus status);
}

final quoteApiProvider = Provider<QuoteApi>(
  (ref) => throw StateError('QuoteApi must be overridden.'),
);

final quotesProvider = FutureProvider<List<SalesQuote>>(
  (ref) => ref.watch(quoteApiProvider).getQuotes(),
);
