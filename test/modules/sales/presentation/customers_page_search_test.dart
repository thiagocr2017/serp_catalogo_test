import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/sales/api/customer_api.dart';
import 'package:serp/modules/sales/presentation/pages/customers_page.dart';

void main() {
  testWidgets('clientes busca desde tres caracteres y limpia al borrar', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/sales/customers',
      routes: [
        GoRoute(
          path: '/sales/customers',
          builder: (_, _) => const CustomersPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customersProvider.overrideWith(
            (ref) async => const [
              CustomerDto(id: 'one', name: 'Alfa Uno'),
              CustomerDto(id: 'two', name: 'Alfa Dos'),
            ],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Buscar cliente',
    );
    await tester.enterText(search, 'Al');
    await tester.pumpAndSettle();
    expect(find.text('Alfa Uno'), findsOneWidget);
    expect(find.text('Alfa Dos'), findsOneWidget);

    await tester.enterText(search, 'Alf');
    await tester.pumpAndSettle();
    expect(find.text('Alfa Uno'), findsOneWidget);
    expect(find.text('Alfa Dos'), findsOneWidget);

    await tester.enterText(search, 'Alfa U');
    await tester.pumpAndSettle();
    expect(find.text('Alfa Uno'), findsOneWidget);
    expect(find.text('Alfa Dos'), findsNothing);

    await tester.enterText(search, 'Al');
    await tester.pumpAndSettle();
    expect(find.text('Alfa Uno'), findsOneWidget);
    expect(find.text('Alfa Dos'), findsOneWidget);
  });
}
