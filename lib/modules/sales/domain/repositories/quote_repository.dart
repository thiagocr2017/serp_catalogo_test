import '../entities/sales_quote.dart';

abstract interface class QuoteRepository {
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
  Future<SalesQuote> updateQuote({
    required String id,
    required String customerId,
    required String customerName,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  });
}

class QuoteLineInput {
  const QuoteLineInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    this.productSku,
    this.productName,
    this.presentationName,
    this.unitsPerPresentation = 1,
  });

  final String productId;
  final int quantity;
  final double unitPrice;
  final double discountPercent;
  final String? productSku;
  final String? productName;
  final String? presentationName;
  final int unitsPerPresentation;
}
