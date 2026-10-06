import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/sales/api/quote_api.dart';
import 'package:serp/modules/sales/presentation/pages/quote_detail_page.dart';

void main() {
  testWidgets('detalle muestra cliente, presentacion, totales y edicion', (
    tester,
  ) async {
    final api = _QuoteApi();
    final router = GoRouter(
      initialLocation: '/sales/quotes/quote-1',
      routes: [
        GoRoute(
          path: '/sales/quotes/:id',
          builder: (context, state) =>
              QuoteDetailPage(quoteId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/sales/customers/:id',
          builder: (context, state) => const Scaffold(body: Text('Perfil cliente')),
        ),
        GoRoute(
          path: '/sales/quotes',
          builder: (context, state) => const Scaffold(body: Text('Cotizaciones')),
        ),
        GoRoute(
          path: '/sales/quotes/:id/edit',
          builder: (context, state) => const Scaffold(body: Text('Editar documento')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [quoteApiProvider.overrideWithValue(api)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('COT-000001'), findsOneWidget);
    expect(find.text('Tienda Demo'), findsOneWidget);
    expect(find.text('Set de utensilios'), findsOneWidget);
    expect(find.textContaining('Caja · 6 unidades c/u'), findsOneWidget);
    expect(find.text('CRC 25.00'), findsWidgets);
    await tester.tap(find.widgetWithText(ListTile, 'Tienda Demo'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil cliente'), findsOneWidget);

    router.go('/sales/quotes/quote-1');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar cotización'));
    await tester.pumpAndSettle();
    expect(find.text('Editar documento'), findsOneWidget);
  });
}

class _QuoteApi implements QuoteApi {
  @override
  Future<List<SalesQuoteDto>> getQuotes() async => [_quote];

  @override
  Future<SalesQuoteDto?> getQuoteById(String id) async => id == _quote.id
      ? _quote
      : null;

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
  }) async => _quote;

  @override
  Future<SalesQuoteDto> updateQuoteStatus(String id, QuoteStatus status) async =>
      _quote;

  @override
  Future<SalesQuoteDto> updateQuote({
    required String id,
    required String customerId,
    required String customerName,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  }) async => _quote;
}

final _quote = SalesQuoteDto(
  id: 'quote-1',
  quoteNumber: 'COT-000001',
  customerId: 'customer-1',
  customerName: 'Tienda Demo',
  status: QuoteStatus.draft,
  totalAmount: 25,
  currencyCode: 'CRC',
  lines: const [
    SalesQuoteLineDto(
      id: 'line-1',
      quoteId: 'quote-1',
      productId: 'product-1',
      quantity: 6,
      unitPrice: 4.1667,
      totalPrice: 25,
      productSku: 'SKU-1',
      productName: 'Set de utensilios',
      presentationName: 'Caja',
      unitsPerPresentation: 6,
    ),
  ],
);
