import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:serp/core/configuration/app_configuration.dart';
import 'package:serp/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('anonimo no puede confirmar devolucion ni mutar documentos', (
    tester,
  ) async {
    final backend = Uri.parse(AppConfiguration.local().supabaseUrl);
    expect(
      const {'localhost', '127.0.0.1', '::1'}.contains(backend.host),
      isTrue,
      reason: 'E2E solo puede escribir en Supabase local.',
    );

    await app.main();
    await tester.pumpAndSettle();
    final client = Supabase.instance.client;
    final candidates = await client
        .from('sales_invoices')
        .select('id, invoice_number, customer_id, customer_name, notes')
        .eq('status', 'CONFIRMED')
        .like('notes', 'E2E factura %')
        .order('created_at', ascending: false)
        .limit(20);
    Map<String, dynamic>? invoice;
    for (final candidate in candidates) {
      final returns = await client
          .from('sales_returns')
          .select('id')
          .eq('invoice_id', candidate['id'] as String);
      if (returns.isEmpty) {
        invoice = candidate;
        break;
      }
    }
    if (invoice == null) {
      throw StateError(
        'Ejecuta antes sales_invoice_lifecycle_flow_test.dart para crear una factura E2E aun no devuelta.',
      );
    }
    final invoiceLines = await client
        .from('sales_invoice_lines')
        .select('id, product_id, quantity, product_name, product_sku')
        .eq('invoice_id', invoice['id'] as String);
    if (invoiceLines.isEmpty) {
      throw StateError('La factura E2E no contiene lineas para devolver.');
    }
    final line = invoiceLines.first;
    final beforeBalances = await client
        .from('inventory_balances')
        .select('product_id, location_id, quantity')
        .eq('product_id', line['product_id'] as String);
    final beforeStock = {
      for (final row in beforeBalances)
        row['location_id'] as String: row['quantity'] as int,
    };
    final marker = '${invoice['invoice_number']} devolucion E2E';

    await tester.tap(find.widgetWithText(ExpansionTile, 'Ventas'));
    await tester.pumpAndSettle();
    final invoicesLink = find.text('Facturas').last;
    await _ensureCentered(tester, invoicesLink);
    await tester.tap(invoicesLink);
    await tester.pumpAndSettle();
    final invoiceNumber = find.text(invoice['invoice_number'] as String).last;
    await _ensureCentered(tester, invoiceNumber);
    await tester.tap(invoiceNumber);
    await tester.pumpAndSettle();
    expect(find.text('Detalle de factura'), findsOneWidget);
    await tester.tap(find.text('Iniciar devolución'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva devolución'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo de devolución *'),
      marker,
    );
    final productLabel =
        line['product_name'] as String? ?? line['product_sku'] as String;
    final productOption = find.text(productLabel).last;
    await _ensureCentered(tester, productOption);
    await tester.tap(productOption);
    await tester.pumpAndSettle();
    final confirm = find.text('Confirmar devolución');
    await _ensureCentered(tester, confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final returned = await client
        .from('sales_returns')
        .select('id')
        .eq('invoice_id', invoice['id'] as String)
        .maybeSingle();
    expect(returned, isNull);
    expect(
      find.textContaining(
        'permission denied for function sales_confirm_return',
      ),
      findsOneWidget,
    );
    final afterBalances = await client
        .from('inventory_balances')
        .select('product_id, location_id, quantity')
        .eq('product_id', line['product_id'] as String);
    final afterStock = {
      for (final row in afterBalances)
        row['location_id'] as String: row['quantity'] as int,
    };
    expect(afterStock, beforeStock);
  });
}

Future<void> _ensureCentered(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.5,
  );
  await tester.pump();
}
