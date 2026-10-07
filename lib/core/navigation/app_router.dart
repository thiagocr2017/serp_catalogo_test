import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../modules/authorization/authorization_module.dart';
import '../../modules/configuration/configuration_module.dart';
import '../../modules/inventory/inventory_module.dart';
import '../../modules/payments/payments_module.dart';
import '../../modules/product/product_module.dart';
import '../../modules/sales/sales_module.dart';
import '../../shared/widgets/desktop_shell_widget.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final refreshNotifier = ValueNotifier<int>(0);
  var isDisposed = false;
  final subscription = repository.authStateChanges.listen((_) {
    if (!isDisposed) {
      refreshNotifier.value++;
    }
  });
  ref.onDispose(() {
    isDisposed = true;
    subscription.cancel();
    refreshNotifier.dispose();
  });

  return GoRouter(
    initialLocation: '/products',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isAuth = repository.currentUser != null;
      final hasTrailingSlash =
          state.uri.path.endsWith('/') && state.uri.path.length > 1;
      final path = hasTrailingSlash
          ? state.uri.path.substring(0, state.uri.path.length - 1)
          : state.uri.path;
      final isLoggingIn = path == '/login';

      if (!isAuth) {
        if (!isLoggingIn || hasTrailingSlash) return '/login';
        return null;
      }

      if (isLoggingIn || path == '/') return '/products';
      if (hasTrailingSlash) return path;

      return null;
    },
    routes: [
      ...authorizationRoutes,
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
});
