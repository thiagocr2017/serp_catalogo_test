import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/shared/widgets/desktop_shell_widget.dart';

void main() {
  testWidgets('el menu de Productos navega al indice desde un detalle', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/products/product-1',
      routes: [
        ShellRoute(
          builder: (context, state, child) => DesktopShellWidget(
            currentLocation: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/products',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Indice productos')),
              ),
            ),
            GoRoute(
              path: '/products/:id',
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Detalle producto')),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Detalle producto'), findsOneWidget);
    await tester.tap(find.text('Lista de productos'));
    await tester.pumpAndSettle();

    expect(find.text('Indice productos'), findsOneWidget);
  });
}
