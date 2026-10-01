import 'package:go_router/go_router.dart';

import '../presentation/pages/payments_page.dart';

final paymentRoutes = [
  GoRoute(
    path: '/payments',
    builder: (context, state) => const PaymentsPage(),
  ),
];
