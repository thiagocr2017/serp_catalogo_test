import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:serp/core/configuration/app_configuration.dart';
import 'package:serp/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crear consignacion envia stock y abre el detalle', (
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
        .limit(20);
    final warehouses = await client
        .from('warehouses')
        .select('id, name, is_default')
        .eq('is_active', true)
        .order('is_default', ascending: false);
    final locations = await client
        .from('inventory_locations')
        .select('id, warehouse_id, code, name, is_default, stock_role')
        .eq('is_active', true)
        .eq('stock_role', 'SELLABLE');
    if (customers.isEmpty || products.isEmpty || warehouses.isEmpty) {
      throw StateError(
        'E2E de Consignaciones requiere cliente, producto y bodega activos.',
      );
    }

    final balances = await client
        .from('inventory_balances')
        .select(
          'product_id, warehouse_id, location_id, quantity, reserved_quantity',
        )
        .inFilter(
          'product_id',
          products.map((row) => row['id'] as String).toList(),
        );
    Map<String, dynamic>? product;
    Map<String, dynamic>? warehouse;
    Map<String, dynamic>? location;
    var available = 0;
    for (final candidate in products) {
      for (final candidateWarehouse in warehouses) {
        final candidateLocations = locations.where(
          (row) => row['warehouse_id'] == candidateWarehouse['id'],
        );
        for (final candidateLocation in candidateLocations) {
          final quantity = balances
              .where(
                (row) =>
                    row['product_id'] == candidate['id'] &&
                    row['warehouse_id'] == candidateWarehouse['id'] &&
                    row['location_id'] == candidateLocation['id'],
              )
              .fold<int>(
                0,
                (sum, row) =>
                    sum +
                    (row['quantity'] as int) -
                    (row['reserved_quantity'] as int),
              );
          if (quantity > 0) {
            product = candidate;
            warehouse = candidateWarehouse;
            location = candidateLocation;
            available = quantity;
            break;
          }
        }
        if (product != null) break;
      }
      if (product != null) break;
    }
    if (product == null || warehouse == null || location == null) {
      throw StateError(
        'E2E de Consignaciones requiere saldo vendible positivo en una ubicacion.',
      );
    }

    final customer = customers.first;
    final customerDisplay = customer['display_name'] as String?;
    final customerOption = customerDisplay?.trim().isNotEmpty == true
        ? '${customerDisplay!.trim()} · ${customer['name']}'
        : customer['name'] as String;
    final productLabel = '${product['sku']} · ${product['name']}';
    final locationLabel = '${location['code']} · ${location['name']}';
    final marker = const Uuid().v4().substring(0, 8);
    final notes = 'E2E consignacion $marker';

    await tester.tap(find.widgetWithText(ExpansionTile, 'Ventas'));
    await tester.pumpAndSettle();
    final consignmentsLink = find.text('Consignaciones').last;
    await _ensureCentered(tester, consignmentsLink);
    await tester.tap(consignmentsLink);
    await tester.pumpAndSettle();
    final newConsignment = find.text('Nueva consignación');
    await _ensureCentered(tester, newConsignment);
    await tester.tap(newConsignment);
    await tester.pumpAndSettle();
    await _selectDropdown(tester, 'Cliente *', customerOption);
    await _selectDropdown(tester, 'Agregar producto', productLabel);
    final addProduct = find.byTooltip('Agregar producto a las líneas');
    await _ensureCentered(tester, addProduct);
    await tester.tap(addProduct);
    await tester.pumpAndSettle();
    await _selectDropdown(
      tester,
      'Bodega de salida *',
      warehouse['name'] as String,
    );
    await _selectDropdown(tester, 'Ubicación de salida *', locationLabel);
    await _enterField(tester, 'Notas', notes);
    final save = find.text('Guardar documento');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final row = await client
        .from('sales_consignments')
        .select(
          'id, consignment_number, customer_id, customer_name, status, total_amount, inventory_document_id, notes',
        )
        .eq('notes', notes)
        .single();
    expect(row['customer_id'], customer['id']);
    expect(row['status'], 'SENT');
    expect(row['inventory_document_id'], isNotNull);
    expect(row['total_amount'], greaterThan(0));
    final lines = await client
        .from('sales_consignment_lines')
        .select('product_id, quantity, returned_quantity')
        .eq('consignment_id', row['id'] as String);
    expect(lines, hasLength(1));
    final quantity = lines.single['quantity'] as int;
    expect(lines.single['product_id'], product['id']);
    expect(lines.single['returned_quantity'], 0);

    final inventoryDocument = await client
        .from('inventory_documents')
        .select(
          'document_type, status, origin_warehouse_id, origin_location_id',
        )
        .eq('id', row['inventory_document_id'] as String)
        .single();
    expect(inventoryDocument['document_type'], 'CONSIGNMENT');
    expect(inventoryDocument['status'], 'CONFIRMED');
    expect(inventoryDocument['origin_warehouse_id'], warehouse['id']);
    expect(inventoryDocument['origin_location_id'], location['id']);
    final movements = await client
        .from('inventory_transactions')
        .select('quantity, location_id, reason')
        .eq('document_id', row['inventory_document_id'] as String)
        .eq('reason', 'SALE');
    expect(movements, hasLength(1));
    expect(movements.single['quantity'], -quantity);
    expect(movements.single['location_id'], location['id']);

    final balance = await client
        .from('inventory_balances')
        .select('quantity, reserved_quantity')
        .eq('product_id', product['id'] as String)
        .eq('warehouse_id', warehouse['id'] as String)
        .eq('location_id', location['id'] as String)
        .single();
    expect(
      (balance['quantity'] as int) - (balance['reserved_quantity'] as int),
      available - quantity,
    );
    expect(find.text(row['consignment_number'] as String), findsWidgets);
    final consignmentNumber = find
        .text(row['consignment_number'] as String)
        .last;
    await _ensureCentered(tester, consignmentNumber);
    await tester.tap(consignmentNumber);
    await tester.pumpAndSettle();
    expect(find.text('Detalle de consignación'), findsOneWidget);
    await tester.ensureVisible(find.text(product['name'] as String));
    expect(find.text(product['name'] as String), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a consignaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Consignaciones'), findsWidgets);
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
  await _ensureCentered(tester, field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> _selectDropdown(
  WidgetTester tester,
  String label,
  String option,
) async {
  final dropdown = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField &&
        widget.decoration.labelText == label,
  );
  await _ensureCentered(tester, dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  final optionFinder = find.text(option).last;
  await _ensureCentered(tester, optionFinder);
  await tester.tap(optionFinder);
  await tester.pumpAndSettle();
}

Future<void> _ensureCentered(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.5,
  );
  await tester.pump();
}
