import 'package:go_router/go_router.dart';
import '../presentation/pages/login_page.dart';

final List<RouteBase> authorizationRoutes = [
  GoRoute(
    path: '/login',
    builder: (context, state) => const LoginPage(),
  ),
];
