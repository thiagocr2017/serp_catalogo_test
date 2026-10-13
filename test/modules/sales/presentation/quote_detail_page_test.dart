import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/sales/api/quote_api.dart';
import 'package:serp/modules/sales/presentation/pages/quote_detail_page.dart';

void main() {
  testWidgets('aceptar permite posponer o crear factura borrador', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _QuoteApi();
    final router = GoRouter(
      initialLocation: '/sales/quotes/quote-1',
      routes: [
        GoRoute(
          path: '/sales/quotes/:id',
          builder: (context, state) => QuoteDetailPage(
            quoteId: state.pathParameters['id']!,
            returnTo: state.uri.queryParameters['returnTo'],
          ),
        ),
        GoRoute(
          path: '/sales/invoices/:id',
          builder: (context, state) =>
              Scaffold(body: Text('Factura ${state.pathParameters['id']}')),
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

    await tester.scrollUntilVisible(
      find.text('Aceptar'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();
    expect(find.text('Crear factura borrador'), findsWidgets);
    expect(api.draftInvoiceCount, 0);

    await tester.tap(find.text('Más tarde'));
    await tester.pumpAndSettle();
    expect(find.text('Aceptada'), findsOneWidget);
    expect(find.text('Crear factura borrador'), findsOneWidget);

    await tester.tap(find.text('Crear factura borrador'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Crear factura borrador').last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Factura invoice-1'), findsOneWidget);
    expect(api.draftInvoiceCount, 1);
  });

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
          builder: (context, state) =>
              const Scaffold(body: Text('Perfil cliente')),
        ),
        GoRoute(
          path: '/sales/quotes',
          builder: (context, state) =>
              const Scaffold(body: Text('Cotizaciones')),
        ),
        GoRoute(
          path: '/sales/quotes/:id/edit',
          builder: (context, state) =>
              const Scaffold(body: Text('Editar documento')),
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
    expect(find.textContaining('Tipo de cambio'), findsNothing);
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
  SalesQuoteDto currentQuote = _quote;
  int draftInvoiceCount = 0;

  @override
  Future<List<SalesQuoteDto>> getQuotes() async => [currentQuote];

  @override
  Future<SalesQuoteDto?> getQuoteById(String id) async =>
      id == currentQuote.id ? currentQuote : null;

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
  Future<String> createDraftInvoiceFromQuote(String quoteId) async {
    draftInvoiceCount++;
    currentQuote = _copyQuote(
      currentQuote,
      status: QuoteStatus.converted,
      convertedInvoiceId: 'invoice-1',
    );
    return 'invoice-1';
  }

  @override
  Future<SalesQuoteDto> updateQuoteStatus(String id, QuoteStatus status) async {
    currentQuote = _copyQuote(currentQuote, status: status);
    return currentQuote;
  }

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

SalesQuoteDto _copyQuote(
  SalesQuoteDto quote, {
  required QuoteStatus status,
  String? convertedInvoiceId,
}) => SalesQuoteDto(
  id: quote.id,
  quoteNumber: quote.quoteNumber,
  customerId: quote.customerId,
  customerName: quote.customerName,
  status: status,
  totalAmount: quote.totalAmount,
  currencyCode: quote.currencyCode,
  exchangeRate: quote.exchangeRate,
  validUntil: quote.validUntil,
  notes: quote.notes,
  agentId: quote.agentId,
  convertedInvoiceId: convertedInvoiceId ?? quote.convertedInvoiceId,
  lines: quote.lines,
  createdAt: quote.createdAt,
  updatedAt: quote.updatedAt,
);

final _quote = SalesQuoteDto(
  id: 'quote-1',
  quoteNumber: 'COT-000001',
  customerId: 'customer-1',
  customerName: 'Tienda Demo',
  status: QuoteStatus.draft,
  totalAmount: 25,
  currencyCode: 'CRC',
  exchangeRate: 2,
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
