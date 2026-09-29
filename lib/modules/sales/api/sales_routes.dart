import 'package:go_router/go_router.dart';

import '../presentation/pages/agent_page.dart';

final List<RouteBase> salesRoutes = [
  GoRoute(
    path: '/sales/agents',
    builder: (context, state) => const AgentPage(),
  ),
];
