import 'package:go_router/go_router.dart';

import '../../modules/inventory/inventory_module.dart';
import '../../modules/product/product_module.dart';
import '../../modules/sales/sales_module.dart';
import '../configuration/settings_page.dart';
import '../../shared/widgets/desktop_shell_widget.dart';

final appRouter = GoRouter(
  initialLocation: '/products',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          DesktopShellWidget(currentLocation: state.uri.path, child: child),
      routes: [
        ...productRoutes,
        ...inventoryRoutes,
        ...salesRoutes,
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
