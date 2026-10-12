import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/sales/api/consignment_api.dart';
import 'package:serp/modules/sales/api/order_api.dart';
import 'package:serp/modules/sales/api/return_api.dart';
import 'package:serp/modules/sales/api/sales_invoice_api.dart';
import 'package:serp/modules/sales/presentation/pages/consignment_detail_page.dart';
import 'package:serp/modules/sales/presentation/pages/order_detail_page.dart';
import 'package:serp/modules/sales/presentation/pages/orders_page.dart';
import 'package:serp/modules/sales/presentation/pages/return_detail_page.dart';
import 'package:serp/modules/sales/presentation/pages/sales_invoice_detail_page.dart';

void main() {
  testWidgets('detalle de devolucion vuelve al indice', (tester) async {
    final router = GoRouter(
      initialLocation: '/sales/returns/return-1',
      routes: [
        GoRoute(
          path: '/sales/returns',
          builder: (context, state) =>
              const Scaffold(body: Text('Lista devoluciones')),
        ),
        GoRoute(
          path: '/sales/returns/:id',
          builder: (context, state) => ReturnDetailPage(
            returnId: state.pathParameters['id']!,
            returnTo: state.uri.queryParameters['returnTo'],
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [returnApiProvider.overrideWithValue(_ReturnApi())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DEV-001'), findsOneWidget);
    expect(find.text('Producto devuelto'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a devoluciones'));
    await tester.pumpAndSettle();
    expect(find.text('Lista devoluciones'), findsOneWidget);
  });

  testWidgets('detalle de consignacion muestra saldo de lineas y vuelve', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/sales/consignments/consignment-1',
      routes: [
        GoRoute(
          path: '/sales/consignments',
          builder: (context, state) =>
              const Scaffold(body: Text('Lista consignaciones')),
        ),
        GoRoute(
          path: '/sales/consignments/:id',
          builder: (context, state) => ConsignmentDetailPage(
            consignmentId: state.pathParameters['id']!,
            returnTo: state.uri.queryParameters['returnTo'],
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consignmentApiProvider.overrideWithValue(_ConsignmentApi()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CON-001'), findsOneWidget);
    expect(find.text('Enviados: 2'), findsOneWidget);
    expect(find.textContaining('Devueltos: 1'), findsOneWidget);
    expect(find.textContaining('Pendientes de devolución: 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a consignaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Lista consignaciones'), findsOneWidget);
  });

  testWidgets('pedido muestra sus líneas y vuelve al listado filtrado', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation:
          '/sales/orders?customerId=customer-1&customerName=Cliente%20Pedido',
      routes: [
        GoRoute(
          path: '/sales/orders',
          builder: (context, state) => OrdersPage(
            customerId: state.uri.queryParameters['customerId'],
            customerName: state.uri.queryParameters['customerName'],
          ),
        ),
        GoRoute(
          path: '/sales/orders/:id',
          builder: (context, state) => OrderDetailPage(
            orderId: state.pathParameters['id']!,
            returnTo: state.uri.queryParameters['returnTo'],
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderApiProvider.overrideWithValue(_OrderApi())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PED-001'));
    await tester.pumpAndSettle();
    expect(find.text('PED-001'), findsOneWidget);
    expect(find.text('Pedido de prueba'), findsOneWidget);
    expect(find.textContaining('Tipo de cambio'), findsNothing);
    await tester.tap(find.byTooltip('Volver a pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('Pedidos del cliente'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.queryParameters, {
      'customerId': 'customer-1',
      'customerName': 'Cliente Pedido',
    });
  });

  testWidgets('factura presenta cliente y líneas sin exponer tasa histórica', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/sales/invoices/invoice-1',
      routes: [
        GoRoute(
          path: '/sales/invoices/:id',
          builder: (context, state) =>
              SalesInvoiceDetailPage(invoiceId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/sales/returns/new',
          builder: (context, state) => const Scaffold(body: Text('Devolución')),
        ),
        GoRoute(
          path: '/sales/customers/:id',
          builder: (context, state) =>
              const Scaffold(body: Text('Perfil cliente')),
        ),
        GoRoute(
          path: '/sales/invoices',
          builder: (context, state) => const Scaffold(body: Text('Facturas')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [salesInvoiceApiProvider.overrideWithValue(_InvoiceApi())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FAC-001'), findsOneWidget);
    expect(find.textContaining('Tipo de cambio'), findsNothing);
    expect(find.text('Producto facturado'), findsOneWidget);
    expect(find.text('CRC 30.00'), findsWidgets);
    expect(find.text('Confirmada'), findsOneWidget);
  });
}

class _ReturnApi implements ReturnApi {
  @override
  Future<List<SalesReturnDto>> getReturns() async => [_return];

  @override
  Future<SalesReturnDto?> getReturnById(String id) async =>
      id == _return.id ? _return : null;

  @override
  Future<SalesReturnPreviewDto> previewReturn(String invoiceId) =>
      throw UnimplementedError();

  @override
  Future<SalesReturnDto> confirmReturn(
    ConfirmSalesReturnCommand command,
  ) async => _return;

  @override
  Future<SalesReturnDto> createReturn({
    required String invoiceId,
    required String customerId,
    required String customerName,
    required String reason,
    required List<ReturnLineInput> lines,
  }) async => _return;
}

class _ConsignmentApi implements ConsignmentApi {
  @override
  Future<List<SalesConsignmentDto>> getConsignments() async => [_consignment];

  @override
  Future<SalesConsignmentDto?> getConsignmentById(String id) async =>
      id == _consignment.id ? _consignment : null;

  @override
  Future<SalesConsignmentDto> createConsignment({
    required String customerId,
    required String customerName,
    required String currencyCode,
    String? notes,
    String? agentId,
    required List<ConsignmentLineInput> lines,
    required String warehouseId,
    required String? locationId,
  }) async => _consignment;

  @override
  Future<SalesConsignmentDto> registerReturn({
    required String consignmentId,
    required String productId,
    required int quantity,
  }) async => _consignment;
}

class _OrderApi implements OrderApi {
  @override
  Future<List<SalesOrderDto>> getOrders() async => [_order];

  @override
  Future<SalesOrderDto?> getOrderById(String id) async =>
      id == _order.id ? _order : null;

  @override
  Future<SalesOrderDto> createOrder({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    String? agentId,
    String? quoteId,
    required List<OrderLineInput> lines,
    required String warehouseId,
    required String? locationId,
  }) async => _order;

  @override
  Future<SalesOrderDto> cancelOrder(String id) async => _order;
}

class _InvoiceApi implements SalesInvoiceApi {
  @override
  Future<List<SalesInvoiceDto>> getInvoices() async => [_invoice];

  @override
  Future<SalesInvoiceDto?> getInvoiceById(String id) async =>
      id == _invoice.id ? _invoice : null;

  @override
  Future<SalesInvoiceDto> createInvoice({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    required List<SalesInvoiceLineInput> lines,
    required String warehouseId,
  }) async => _invoice;

  @override
  Future<SalesInvoiceDto> cancelInvoice(
    String id, {
    required String reason,
  }) async => _invoice;
}

final _return = SalesReturnDto(
  id: 'return-1',
  returnNumber: 'DEV-001',
  customerName: 'Cliente Uno',
  customerId: 'customer-1',
  invoiceId: 'invoice-1',
  status: ReturnStatus.confirmed,
  totalAmount: 12,
  currencyCode: 'CRC',
  reason: 'Producto defectuoso',
  lines: const [
    SalesReturnLineDto(
      id: 'return-line-1',
      returnId: 'return-1',
      productId: 'product-1',
      invoiceLineId: 'invoice-line-1',
      productName: 'Producto devuelto',
      quantity: 1,
      unitPrice: 12,
      totalPrice: 12,
    ),
  ],
);

final _consignment = SalesConsignmentDto(
  id: 'consignment-1',
  consignmentNumber: 'CON-001',
  customerName: 'Cliente Dos',
  customerId: 'customer-2',
  status: ConsignmentStatus.partialReturn,
  totalAmount: 24,
  returnedAmount: 12,
  currencyCode: 'CRC',
  lines: const [
    SalesConsignmentLineDto(
      id: 'consignment-line-1',
      consignmentId: 'consignment-1',
      productId: 'product-2',
      productName: 'Vaso',
      quantity: 2,
      returnedQuantity: 1,
      unitPrice: 12,
      totalPrice: 24,
    ),
  ],
);

final _order = SalesOrderDto(
  id: 'order-1',
  orderNumber: 'PED-001',
  customerName: 'Cliente Pedido',
  customerId: 'customer-1',
  status: OrderStatus.confirmed,
  totalAmount: 20,
  currencyCode: 'CRC',
  exchangeRate: 2,
  lines: const [
    SalesOrderLineDto(
      id: 'order-line-1',
      orderId: 'order-1',
      productId: 'product-1',
      productName: 'Pedido de prueba',
      productSku: 'P-1',
      quantity: 2,
      unitPrice: 10,
      totalPrice: 20,
    ),
  ],
);

final _invoice = SalesInvoiceDto(
  id: 'invoice-1',
  invoiceNumber: 'FAC-001',
  customerName: 'Cliente Factura',
  customerId: 'customer-1',
  status: SalesInvoiceStatus.confirmed,
  totalAmount: 30,
  currencyCode: 'CRC',
  exchangeRate: 2,
  lines: const [
    SalesInvoiceLineDto(
      id: 'invoice-line-1',
      invoiceId: 'invoice-1',
      productId: 'product-1',
      productName: 'Producto facturado',
      quantity: 3,
      unitPrice: 10,
      totalPrice: 30,
    ),
  ],
);
