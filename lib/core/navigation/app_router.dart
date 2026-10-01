import 'package:go_router/go_router.dart';

import '../../modules/configuration/configuration_module.dart';
import '../../modules/inventory/inventory_module.dart';
import '../../modules/payments/payments_module.dart';
import '../../modules/product/product_module.dart';
import '../../modules/sales/sales_module.dart';
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
        ...paymentRoutes,
        ...configurationRoutes,
      ],
    ),
  ],
);
