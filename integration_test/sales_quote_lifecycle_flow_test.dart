import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:serp/core/configuration/app_configuration.dart';
import 'package:serp/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crear, editar y enviar una cotizacion conserva su historial', (
    tester,
  ) async {
    final configuration = AppConfiguration.local();
    final backend = Uri.parse(configuration.supabaseUrl);
    expect(
      const {'localhost', '127.0.0.1', '::1'}.contains(backend.host),
      isTrue,
      reason: 'E2E solo puede escribir en Supabase local.',
    );

    await app.main();
    await tester.pumpAndSettle();
    final client = Supabase.instance.client;
    final customers = await client
        .from('customers')
        .select('id, name, display_name')
        .eq('is_active', true)
        .like('name', 'Cliente E2E %')
        .order('created_at', ascending: false)
        .limit(1);
    final products = await client
        .from('products')
        .select('id, sku, name')
        .eq('is_active', true)
        .like('sku', 'E2E-%')
        .order('created_at', ascending: false)
        .limit(1);
    if (customers.isEmpty || products.isEmpty) {
      throw StateError(
        'E2E de Cotizaciones requiere ejecutar primero los flujos E2E de '
        'Clientes y Productos para dejar fixtures activos en Supabase local.',
      );
    }
    final customer = customers.first;
    final product = products.first;
    final marker = const Uuid().v4().substring(0, 8);
    final originalNotes = 'E2E cotizacion $marker';
    final editedNotes = 'E2E cotizacion editada $marker';
    final customerLabel = customer['display_name'] as String?;
    final customerName = customerLabel?.trim().isNotEmpty == true
        ? customerLabel!.trim()
        : customer['name'] as String;
    final productLabel = '${product['sku']} · ${product['name']}';

    await tester.tap(find.widgetWithText(ExpansionTile, 'Ventas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cotizaciones').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva cotización'));
    await tester.pumpAndSettle();

    await _enterField(
      tester,
      'Buscar cliente *',
      customerLabel ?? customer['name'] as String,
    );
    await tester.pumpAndSettle();
    final customerOption = find.text(
      customerLabel?.trim().isNotEmpty == true
          ? customerLabel!.trim()
          : customer['name'] as String,
    );
    await tester.tap(customerOption.last);
    await tester.pumpAndSettle();

    await _enterField(tester, 'Buscar producto', product['sku'] as String);
    await tester.pumpAndSettle();
    await tester.tap(find.text(productLabel).last);
    await tester.pumpAndSettle();
    expect(find.text(productLabel), findsWidgets);

    await _enterField(tester, 'Notas', originalNotes);
    final createButton = find.text('Guardar borrador');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final created = await client
        .from('sales_quotes')
        .select(
          'id, quote_number, customer_id, customer_name, status, currency_code, exchange_rate, notes, total_amount',
        )
        .eq('notes', originalNotes)
        .single();
    final quoteId = created['id'] as String;
    expect(created['customer_id'], customer['id']);
    expect(created['customer_name'], customerName);
    expect(created['status'], 'DRAFT');
    expect(created['exchange_rate'], 1);
    expect(created['total_amount'], greaterThan(0));

    final createdLines = await client
        .from('sales_quote_lines')
        .select(
          'product_id, quantity, unit_price, total_price, product_sku, product_name, units_per_presentation',
        )
        .eq('quote_id', quoteId);
    expect(createdLines, hasLength(1));
    expect(createdLines.single['product_id'], product['id']);
    expect(createdLines.single['product_sku'], product['sku']);
    expect(createdLines.single['quantity'], greaterThan(0));

    await tester.tap(find.text(created['quote_number'] as String));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de cotización'), findsOneWidget);
    expect(find.text(customerName), findsWidgets);
    await tester.tap(find.byTooltip('Editar cotización'));
    await tester.pumpAndSettle();
    await _enterField(tester, 'Notas', editedNotes);
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final updated = await client
        .from('sales_quotes')
        .select('id, status, notes, total_amount')
        .eq('id', quoteId)
        .single();
    expect(updated['status'], 'DRAFT');
    expect(updated['notes'], editedNotes);
    expect(updated['total_amount'], created['total_amount']);
    expect(find.text('Detalle de cotización'), findsOneWidget);

    await tester.tap(find.text('Marcar enviada'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final sent = await client
        .from('sales_quotes')
        .select('status, notes')
        .eq('id', quoteId)
        .single();
    expect(sent['status'], 'SENT');
    expect(sent['notes'], editedNotes);
    expect(find.text('Enviada'), findsWidgets);
    expect(find.byTooltip('Editar cotización'), findsNothing);
  });
}

Future<void> _enterField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final decorator = find.byWidgetPredicate(
    (widget) =>
        widget is InputDecorator && widget.decoration.labelText == label,
  );
  final field = find.descendant(
    of: decorator,
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}
