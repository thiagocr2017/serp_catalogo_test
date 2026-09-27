import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../modules/product/presentation/pages/product_form_page.dart';
import '../../modules/product/presentation/pages/product_list_page.dart';
import '../../shared/widgets/desktop_shell_widget.dart';

final appRouter = GoRouter(
  initialLocation: '/products',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          DesktopShellWidget(currentLocation: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductListPage(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const ProductFormPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/categories',
          builder: (context, state) => const _PendingPage(title: 'Categorías'),
        ),
        GoRoute(
          path: '/promotions',
          builder: (context, state) => const _PendingPage(title: 'Promociones'),
        ),
        GoRoute(
          path: '/catalog-export',
          builder: (context, state) =>
              const _PendingPage(title: 'Generar catálogo PDF'),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              const _PendingPage(title: 'Configuración'),
        ),
      ],
    ),
  ],
);

class _PendingPage extends StatelessWidget {
  const _PendingPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title se implementará en su módulo.')),
    );
  }
}
