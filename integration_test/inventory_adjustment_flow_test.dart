import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:serp/core/configuration/app_configuration.dart';
import 'package:serp/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('confirmar ajuste registra documento, movimiento y saldo', (
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
    final products = await client
        .from('products')
        .select('id, sku, name, current_stock')
        .eq('is_active', true)
        .order('sku')
        .limit(1);
    if (products.isEmpty) {
      throw StateError('Ejecuta primero el E2E de Productos.');
    }
    final product = products.first;
    final warehouse = await client
        .from('warehouses')
        .select('id')
        .eq('is_active', true)
        .eq('is_default', true)
        .single();
    final location = await client
        .from('inventory_locations')
        .select('id')
        .eq('warehouse_id', warehouse['id'] as String)
        .eq('is_active', true)
        .eq('is_default', true)
        .single();
    final baseline = await client
        .from('inventory_balances')
        .select('quantity')
        .eq('product_id', product['id'] as String)
        .eq('location_id', location['id'] as String)
        .maybeSingle();
    final initialBalance = baseline == null ? 0 : baseline['quantity'] as int;

    final marker = 'E2E-INV-${const Uuid().v4()}';
    const adjustment = 2;
    await tester.ensureVisible(find.text('Inventario').first);
    await tester.tap(find.text('Inventario').first);
    await tester.pumpAndSettle();
    final movementsLink = find.text('Movimientos').first;
    await tester.ensureVisible(movementsLink);
    await tester.tap(movementsLink);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo documento').first);
    await tester.pumpAndSettle();

    await _enterTextField(tester, 'Referencia externa opcional', marker);
    await _enterTextField(tester, 'Motivo u observaciones', marker);
    final productSearch = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Producto',
    );
    await tester.ensureVisible(productSearch);
    await tester.enterText(productSearch, product['sku'] as String);
    await tester.pumpAndSettle();
    final option = find.text('${product['sku']} · ${product['name']}').last;
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    await _enterTextField(tester, 'Cantidad', '$adjustment');

    final confirm = find.text('Confirmar ajuste');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final document = await client
        .from('inventory_documents')
        .select(
          'id, document_number, document_type, status, '
          'destination_location_id, external_reference, notes',
        )
        .eq('external_reference', marker)
        .single();
    expect(document['document_type'], 'ADJUSTMENT');
    expect(document['status'], 'CONFIRMED');
    expect(document['destination_location_id'], location['id']);
    expect(document['notes'], marker);
    expect(find.text(document['document_number'] as String), findsOneWidget);

    final lines = await client
        .from('inventory_document_lines')
        .select('product_id, quantity')
        .eq('document_id', document['id'] as String);
    expect(lines, hasLength(1));
    expect(lines.single['product_id'], product['id']);
    expect(lines.single['quantity'], adjustment);

    final movements = await client
        .from('inventory_transactions')
        .select('quantity, reason, document_id, location_id')
        .eq('document_id', document['id'] as String);
    expect(movements, hasLength(1));
    expect(movements.single['quantity'], adjustment);
    expect(movements.single['reason'], 'ADJUSTMENT');
    expect(movements.single['location_id'], location['id']);

    final updatedBalance = await client
        .from('inventory_balances')
        .select('quantity')
        .eq('product_id', product['id'] as String)
        .eq('location_id', location['id'] as String)
        .single();
    expect(updatedBalance['quantity'], initialBalance + adjustment);

    await tester.tap(find.byTooltip('Volver a documentos'));
    await tester.pumpAndSettle();
    expect(find.text('Documentos de inventario'), findsOneWidget);
    expect(find.text(document['document_number'] as String), findsOneWidget);
  });
}

Future<void> _enterTextField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}
