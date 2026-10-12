import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/sales/api/customer_api.dart';
import 'package:serp/modules/sales/presentation/pages/customer_import_page.dart';

void main() {
  testWidgets(
    'shows template and file actions, with import unavailable initially',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/sales/customers/import',
        routes: [
          GoRoute(
            path: '/sales/customers/import',
            builder: (_, _) => const CustomerImportPage(),
          ),
          GoRoute(
            path: '/sales/customers',
            builder: (_, _) => const Scaffold(body: Text('Lista de clientes')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerApiProvider.overrideWithValue(_FakeCustomerApi()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Importar clientes'), findsOneWidget);
      expect(find.text('Descargar plantilla'), findsOneWidget);
      expect(find.text('Seleccionar CSV'), findsOneWidget);
      expect(find.textContaining('Crear '), findsNothing);

      await tester.tap(find.byTooltip('Volver a clientes'));
      await tester.pumpAndSettle();
      expect(find.text('Lista de clientes'), findsOneWidget);
    },
  );
}

class _FakeCustomerApi implements CustomerApi {
  @override
  Future<List<CustomerDto>> getCustomers() async => const [];

  @override
  Future<List<CustomerCategoryDto>> getCustomerCategories() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
