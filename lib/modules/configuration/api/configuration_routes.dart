import 'package:go_router/go_router.dart';

import '../presentation/pages/settings_page.dart';

final configurationRoutes = <RouteBase>[
  GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
];
