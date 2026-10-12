import 'package:go_router/go_router.dart';

import '../presentation/pages/agent_page.dart';
import '../presentation/pages/customer_profile_page.dart';
import '../presentation/pages/invoices_page.dart';
import '../presentation/pages/sales_invoice_detail_page.dart';
import '../presentation/pages/customers_page.dart';
import '../presentation/pages/customer_import_page.dart';
import '../presentation/pages/quotes_page.dart';
import '../presentation/pages/quote_detail_page.dart';
import '../presentation/pages/orders_page.dart';
import '../presentation/pages/returns_page.dart';
import '../presentation/pages/consignments_page.dart';
import '../presentation/pages/sales_document_form_page.dart';
import '../presentation/pages/return_detail_page.dart';
import '../presentation/pages/consignment_detail_page.dart';
import '../presentation/pages/order_detail_page.dart';

final List<RouteBase> salesRoutes = [
  GoRoute(
    path: '/sales/agents',
    builder: (context, state) => const AgentPage(),
  ),
  GoRoute(
    path: '/sales/invoices',
    builder: (context, state) => const InvoicesPage(),
  ),
  GoRoute(
    path: '/sales/invoices/new',
    builder: (context, state) =>
        const SalesDocumentFormPage(kind: SalesDocumentKind.invoice),
  ),
  GoRoute(
    path: '/sales/invoices/:id',
    builder: (context, state) => SalesInvoiceDetailPage(
      invoiceId: state.pathParameters['id']!,
      returnTo: state.uri.queryParameters['returnTo'],
    ),
  ),
  GoRoute(
    path: '/sales/customers',
    builder: (context, state) => const CustomersPage(),
  ),
  GoRoute(
    path: '/sales/customers/new',
    builder: (context, state) => const CustomerFormPage(),
  ),
  GoRoute(
    path: '/sales/customers/import',
    builder: (context, state) => const CustomerImportPage(),
  ),
  GoRoute(
    path: '/sales/customers/:id',
    builder: (context, state) => CustomerProfilePage(
      customerId: state.pathParameters['id']!,
      returnTo: state.uri.queryParameters['returnTo'],
    ),
  ),
  GoRoute(
    path: '/sales/customers/:id/edit',
    builder: (context, state) =>
        CustomerFormPage(customerId: state.pathParameters['id']),
  ),
  GoRoute(
    path: '/sales/quotes',
    builder: (context, state) => const QuotesPage(),
  ),
  GoRoute(
    path: '/sales/quotes/new',
    builder: (context, state) =>
        const SalesDocumentFormPage(kind: SalesDocumentKind.quote),
  ),
  GoRoute(
    path: '/sales/quotes/:id',
    builder: (context, state) => QuoteDetailPage(
      quoteId: state.pathParameters['id']!,
      returnTo: state.uri.queryParameters['returnTo'],
    ),
  ),
  GoRoute(
    path: '/sales/quotes/:id/edit',
    builder: (context, state) => SalesDocumentFormPage(
      kind: SalesDocumentKind.quote,
      quoteId: state.pathParameters['id']!,
      returnTo: state.uri.queryParameters['returnTo'],
    ),
  ),
  GoRoute(
    path: '/sales/orders',
    builder: (context, state) => OrdersPage(
      customerId: state.uri.queryParameters['customerId'],
      customerName: state.uri.queryParameters['customerName'],
    ),
  ),
  GoRoute(
    path: '/sales/orders/new',
    builder: (context, state) =>
        const SalesDocumentFormPage(kind: SalesDocumentKind.order),
  ),
  GoRoute(
    path: '/sales/orders/:id',
    builder: (context, state) => OrderDetailPage(
      orderId: state.pathParameters['id']!,
      returnTo: state.uri.queryParameters['returnTo'],
    ),
  ),
  GoRoute(
    path: '/sales/returns',
    builder: (context, state) => const ReturnsPage(),
  ),
  GoRoute(
    path: '/sales/returns/new',
    builder: (context, state) => SalesDocumentFormPage(
      kind: SalesDocumentKind.returnItem,
      invoiceId: state.uri.queryParameters['invoiceId'],
      returnTo: state.uri.queryParameters['returnTo'],
    ),
  ),
  GoRoute(
    path: '/sales/returns/:id',
    builder: (context, state) => ReturnDetailPage(
      returnId: state.pathParameters['id']!,
      returnTo: state.uri.queryParameters['returnTo'],
    ),
  ),
  GoRoute(
    path: '/sales/consignments',
    builder: (context, state) => const ConsignmentsPage(),
  ),
  GoRoute(
    path: '/sales/consignments/new',
    builder: (context, state) =>
        const SalesDocumentFormPage(kind: SalesDocumentKind.consignment),
  ),
  GoRoute(
    path: '/sales/consignments/:id',
    builder: (context, state) => ConsignmentDetailPage(
      consignmentId: state.pathParameters['id']!,
      returnTo: state.uri.queryParameters['returnTo'],
    ),
  ),
];
