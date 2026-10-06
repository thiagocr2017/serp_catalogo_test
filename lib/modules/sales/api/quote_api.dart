import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sales_document_dtos.dart';

export 'sales_document_dtos.dart';

abstract interface class QuoteApi {
  Future<List<SalesQuoteDto>> getQuotes();
  Future<SalesQuoteDto?> getQuoteById(String id);
  Future<SalesQuoteDto> createQuote({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  });
  Future<SalesQuoteDto> updateQuoteStatus(String id, QuoteStatus status);
  Future<SalesQuoteDto> updateQuote({
    required String id,
    required String customerId,
    required String customerName,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  });
}

final quoteApiProvider = Provider<QuoteApi>(
  (ref) => throw StateError('QuoteApi must be overridden.'),
);

final quotesProvider = FutureProvider<List<SalesQuoteDto>>(
  (ref) => ref.watch(quoteApiProvider).getQuotes(),
);

final quoteByIdProvider = FutureProvider.family<SalesQuoteDto?, String>(
  (ref, id) => ref.watch(quoteApiProvider).getQuoteById(id),
);
