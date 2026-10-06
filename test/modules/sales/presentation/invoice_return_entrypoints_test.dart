import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/sales/api/consignment_api.dart';
import 'package:serp/modules/sales/api/customer_api.dart';
import 'package:serp/modules/sales/api/order_api.dart';
import 'package:serp/modules/sales/api/quote_api.dart';
import 'package:serp/modules/sales/api/return_api.dart';
import 'package:serp/modules/sales/api/sales_invoice_api.dart';
import 'package:serp/modules/sales/presentation/pages/customer_profile_page.dart';
import 'package:serp/modules/sales/presentation/pages/invoices_page.dart';
import 'package:serp/modules/sales/presentation/pages/orders_page.dart';
import 'package:serp/modules/sales/presentation/pages/sales_invoice_detail_page.dart';

void main() {
  testWidgets('lista de facturas inicia devolucion y conserva el indice', (
    tester,
  ) async {
    await tester.pumpWidget(_app('/sales/invoices', _invoiceRoutes));
    await tester.pumpAndSettle();

    _invokeReturnAction(tester);
    await tester.pumpAndSettle();

    expect(find.text('Factura: invoice-1'), findsOneWidget);
    expect(find.text('Retorno: /sales/invoices'), findsOneWidget);
  });

  testWidgets('detalle de factura inicia devolucion y conserva origen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        '/sales/invoices/invoice-1?returnTo=%2Fsales%2Fcustomers%2Fcustomer-1',
        [
          GoRoute(
            path: '/sales/invoices/:id',
            builder: (context, state) => SalesInvoiceDetailPage(
              invoiceId: state.pathParameters['id']!,
              returnTo: state.uri.queryParameters['returnTo'],
            ),
          ),
          ..._returnRoute,
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar devolución'));
    await tester.pumpAndSettle();

    expect(find.text('Factura: invoice-1'), findsOneWidget);
    expect(find.text('Retorno: /sales/customers/customer-1'), findsOneWidget);
  });

  testWidgets('perfil de cliente inicia devolucion desde su factura', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app('/sales/customers/customer-1', [
        GoRoute(
          path: '/sales/customers/:id',
          builder: (context, state) =>
              CustomerProfilePage(customerId: state.pathParameters['id']!),
        ),
        ..._returnRoute,
      ]),
    );
    await tester.pumpAndSettle();

    final tabs = tester.element(find.byType(TabBar).last);
    DefaultTabController.of(tabs).animateTo(1);
    await tester.pumpAndSettle();
    _invokeReturnAction(tester);
    await tester.pumpAndSettle();

    expect(find.text('Factura: invoice-1'), findsOneWidget);
    expect(find.text('Retorno: /sales/customers/customer-1'), findsOneWidget);
  });

  testWidgets('pendientes abre pedidos filtrados y permite volver al cliente', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app('/sales/orders?customerId=customer-1', [
        GoRoute(
          path: '/sales/orders',
          builder: (context, state) => OrdersPage(
            customerId: state.uri.queryParameters['customerId'],
            customerName: state.uri.queryParameters['customerName'],
          ),
        ),
        GoRoute(
          path: '/sales/customers/:id',
          builder: (_, state) => Scaffold(
            body: Text('Perfil ${state.pathParameters['id']}'),
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('PED-CLIENTE'), findsOneWidget);
    expect(find.text('PED-OTRO'), findsNothing);
    await tester.tap(find.byTooltip('Volver al cliente'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil customer-1'), findsOneWidget);
  });
}

void _invokeReturnAction(WidgetTester tester) {
  final action = tester
      .widgetList<IconButton>(find.byType(IconButton))
      .firstWhere((button) => button.tooltip == 'Iniciar devolución');
  action.onPressed!.call();
}

Widget _app(String initialLocation, List<RouteBase> routes) => ProviderScope(
  overrides: [
    customerApiProvider.overrideWithValue(_CustomerApi()),
    salesInvoiceApiProvider.overrideWithValue(_InvoiceApi()),
    orderApiProvider.overrideWithValue(_OrderApi()),
    quoteApiProvider.overrideWithValue(_QuoteApi()),
    returnApiProvider.overrideWithValue(_ReturnApi()),
    consignmentApiProvider.overrideWithValue(_ConsignmentApi()),
  ],
  child: MaterialApp.router(
    routerConfig: GoRouter(initialLocation: initialLocation, routes: routes),
  ),
);

final _invoiceRoutes = <RouteBase>[
  GoRoute(path: '/sales/invoices', builder: (_, _) => const InvoicesPage()),
  ..._returnRoute,
];

final _returnRoute = <RouteBase>[
  GoRoute(
    path: '/sales/returns/new',
    builder: (context, state) => Scaffold(
      body: Column(
        children: [
          Text('Factura: ${state.uri.queryParameters['invoiceId']}'),
          Text('Retorno: ${state.uri.queryParameters['returnTo']}'),
        ],
      ),
    ),
  ),
];

final _invoice = SalesInvoiceDto(
  id: 'invoice-1',
  invoiceNumber: 'FAC-0001',
  customerId: 'customer-1',
  customerName: 'Cliente Uno',
  status: SalesInvoiceStatus.confirmed,
  totalAmount: 100,
  currencyCode: 'CRC',
);

class _InvoiceApi implements SalesInvoiceApi {
  @override
  Future<List<SalesInvoiceDto>> getInvoices() async => [_invoice];

  @override
  Future<SalesInvoiceDto?> getInvoiceById(String id) async =>
      id == _invoice.id ? _invoice : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CustomerApi implements CustomerApi {
  static const _customer = CustomerDto(id: 'customer-1', name: 'Cliente Uno');

  @override
  Future<CustomerDto?> getCustomerById(String id) async =>
      id == _customer.id ? _customer : null;

  @override
  Future<List<CustomerDto>> getCustomers() async => const [_customer];

  @override
  Future<List<CustomerContactDto>> getCustomerContacts(
    String customerId,
  ) async => const [];

  @override
  Future<CustomerCommercialSummaryDto> getCustomerCommercialSummary(
    String customerId,
  ) async => CustomerCommercialSummaryDto.empty(customerId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OrderApi implements OrderApi {
  @override
  Future<List<SalesOrderDto>> getOrders() async => const [
    SalesOrderDto(
      id: 'order-1',
      orderNumber: 'PED-CLIENTE',
      customerId: 'customer-1',
      customerName: 'Cliente Uno',
      status: OrderStatus.confirmed,
      totalAmount: 100,
      currencyCode: 'CRC',
    ),
    SalesOrderDto(
      id: 'order-2',
      orderNumber: 'PED-OTRO',
      customerId: 'customer-2',
      customerName: 'Otro Cliente',
      status: OrderStatus.confirmed,
      totalAmount: 200,
      currencyCode: 'CRC',
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuoteApi implements QuoteApi {
  @override
  Future<List<SalesQuoteDto>> getQuotes() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReturnApi implements ReturnApi {
  @override
  Future<List<SalesReturnDto>> getReturns() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ConsignmentApi implements ConsignmentApi {
  @override
  Future<List<SalesConsignmentDto>> getConsignments() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
