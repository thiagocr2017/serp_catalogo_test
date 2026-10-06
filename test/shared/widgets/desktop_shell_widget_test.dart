import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/shared/widgets/desktop_shell_widget.dart';

void main() {
  testWidgets('cada pantalla principal de Ventas tiene entrada en el menu', (
    tester,
  ) async {
    const entries = [
      ('Agentes', '/sales/agents'),
      ('Clientes', '/sales/customers'),
      ('Cotizaciones', '/sales/quotes'),
      ('Pedidos', '/sales/orders'),
      ('Facturas', '/sales/invoices'),
      ('Devoluciones', '/sales/returns'),
      ('Consignaciones', '/sales/consignments'),
    ];
    final router = GoRouter(
      initialLocation: '/sales/agents',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              DesktopShellWidget(currentLocation: state.uri.path, child: child),
          routes: [
            for (final (label, path) in entries)
              GoRoute(
                path: path,
                builder: (context, state) =>
                    Scaffold(body: Center(child: Text('Índice $label'))),
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    for (final (label, path) in entries) {
      final item = find.text(label).last;
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.path, path);
      expect(find.text('Índice $label'), findsOneWidget);
    }
  });

  testWidgets('Ventas expande con el mismo patron del menu de Productos', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/sales/quotes',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              DesktopShellWidget(currentLocation: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/sales/quotes',
              builder: (context, state) =>
                  const Scaffold(body: Text('Indice cotizaciones')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Indice cotizaciones'), findsOneWidget);
    expect(find.text('Ventas').hitTestable(), findsOneWidget);
    expect(find.text('Agentes').hitTestable(), findsOneWidget);
    expect(find.text('Cotizaciones').hitTestable(), findsOneWidget);
  });

  testWidgets('el menu de Productos navega al indice desde un detalle', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/products/product-1',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              DesktopShellWidget(currentLocation: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/products',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('Indice productos'))),
            ),
            GoRoute(
              path: '/products/:id',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('Detalle producto'))),
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

  testWidgets('Productos colapsa en detalle sin dejar entradas residuales', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/products/product-1',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              DesktopShellWidget(currentLocation: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/products/:id',
              builder: (context, state) =>
                  const Scaffold(body: Center(child: Text('Detalle producto'))),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('Lista de productos').hitTestable(), findsOneWidget);

    final productGroup = tester.widget<ExpansionTile>(
      find
          .ancestor(
            of: find.text('Productos'),
            matching: find.byType(ExpansionTile),
          )
          .first,
    );
    expect(productGroup.splashColor, Colors.transparent);
    expect(productGroup.enableFeedback, isFalse);

    await tester.tap(find.text('Productos'));
    await tester.pumpAndSettle();

    expect(find.text('Lista de productos').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
