import 'package:go_router/go_router.dart';

import '../presentation/pages/agent_page.dart';
import '../presentation/pages/invoices_page.dart';

final List<RouteBase> salesRoutes = [
  GoRoute(
    path: '/sales/agents',
    builder: (context, state) => const AgentPage(),
  ),
  GoRoute(
    path: '/sales/invoices',
    builder: (context, state) => const InvoicesPage(),
  ),
];
