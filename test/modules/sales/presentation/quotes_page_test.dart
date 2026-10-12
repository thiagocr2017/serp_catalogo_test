import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/sales/api/quote_api.dart';
import 'package:serp/modules/sales/presentation/pages/quotes_page.dart';

void main() {
  testWidgets('busca numero, cliente, producto y SKU con moneda guardada', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('CRC 125.00'), findsOneWidget);
    expect(find.text('USD 40.00'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'sku-blue');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'COT-101'), findsOneWidget);
    expect(find.text('COT-102'), findsNothing);
  });

  testWidgets('combina filtro de estado y muestra cero resultados', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sku-blue');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptada').last);
    await tester.pumpAndSettle();
    expect(
      find.text('No hay cotizaciones para esos criterios.'),
      findsOneWidget,
    );
    expect(find.text('No hay cotizaciones registradas.'), findsNothing);
  });

  testWidgets('muestra KPI y filtra mientras se escribe sin Enter', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Borradores'), findsOneWidget);
    expect(find.text('Aceptadas'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'COT-101');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'COT-101'), findsOneWidget);
    expect(find.text('COT-102'), findsNothing);
  });

  testWidgets('limpiar a menos de tres caracteres restaura cotizaciones', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final search = find.byType(TextField);
    await tester.enterText(search, 'sku-blue');
    await tester.pumpAndSettle();
    expect(find.text('COT-101'), findsOneWidget);
    expect(find.text('COT-102'), findsNothing);

    await tester.enterText(search, 'sk');
    await tester.pumpAndSettle();
    expect(find.text('COT-101'), findsOneWidget);
    expect(find.text('COT-102'), findsOneWidget);
  });

  testWidgets('abrir una fila navega al detalle de esa cotizacion', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [quoteApiProvider.overrideWithValue(_QuotesApi())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('COT-101'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle quote-101'), findsOneWidget);
  });
}

Widget _app() => ProviderScope(
  overrides: [quoteApiProvider.overrideWithValue(_QuotesApi())],
  child: MaterialApp.router(routerConfig: _router()),
);

GoRouter _router() => GoRouter(
  initialLocation: '/sales/quotes',
  routes: [
    GoRoute(
      path: '/sales/quotes',
      builder: (context, state) => const QuotesPage(),
    ),
    GoRoute(
      path: '/sales/quotes/new',
      builder: (context, state) =>
          const Scaffold(body: Text('Nueva cotizacion')),
    ),
    GoRoute(
      path: '/sales/quotes/:id',
      builder: (context, state) =>
          Scaffold(body: Text('Detalle ${state.pathParameters['id']}')),
    ),
  ],
);

class _QuotesApi implements QuoteApi {
  @override
  Future<List<SalesQuoteDto>> getQuotes() async => [_draft, _sent];

  @override
  Future<SalesQuoteDto?> getQuoteById(String id) async => null;

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
  }) async => _draft;

  @override
  Future<SalesQuoteDto> updateQuoteStatus(
    String id,
    QuoteStatus status,
  ) async => _draft;

  @override
  Future<SalesQuoteDto> updateQuote({
    required String id,
    required String customerId,
    required String customerName,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  }) async => _draft;
}

const _draft = SalesQuoteDto(
  id: 'quote-101',
  quoteNumber: 'COT-101',
  customerId: 'customer-1',
  customerName: 'Almacen Norte',
  status: QuoteStatus.draft,
  totalAmount: 125,
  currencyCode: 'CRC',
  lines: [
    SalesQuoteLineDto(
      id: 'line-1',
      quoteId: 'quote-101',
      productId: 'product-1',
      quantity: 2,
      unitPrice: 62.5,
      totalPrice: 125,
      productSku: 'SKU-BLUE',
      productName: 'Vaso azul',
      presentationName: 'Caja',
    ),
  ],
);

const _sent = SalesQuoteDto(
  id: 'quote-102',
  quoteNumber: 'COT-102',
  customerId: 'customer-2',
  customerName: 'Tienda Central',
  status: QuoteStatus.sent,
  totalAmount: 40,
  currencyCode: 'USD',
  lines: [
    SalesQuoteLineDto(
      id: 'line-2',
      quoteId: 'quote-102',
      productId: 'product-2',
      quantity: 1,
      unitPrice: 40,
      totalPrice: 40,
      productSku: 'SKU-RED',
      productName: 'Vaso rojo',
    ),
  ],
);
