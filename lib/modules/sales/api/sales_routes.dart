import 'package:go_router/go_router.dart';

import '../presentation/pages/agent_page.dart';
import '../presentation/pages/invoices_page.dart';
import '../presentation/pages/customers_page.dart';
import '../presentation/pages/quotes_page.dart';
import '../presentation/pages/orders_page.dart';
import '../presentation/pages/returns_page.dart';
import '../presentation/pages/consignments_page.dart';

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
    path: '/sales/customers',
    builder: (context, state) => const CustomersPage(),
  ),
  GoRoute(
    path: '/sales/customers/new',
    builder: (context, state) => const CustomerFormPage(),
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
    path: '/sales/orders',
    builder: (context, state) => const OrdersPage(),
  ),
  GoRoute(
    path: '/sales/returns',
    builder: (context, state) => const ReturnsPage(),
  ),
  GoRoute(
    path: '/sales/consignments',
    builder: (context, state) => const ConsignmentsPage(),
  ),
];
