import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:serp/core/configuration/app_configuration.dart';
import 'package:serp/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crear pedido confirma despacho desde bodega y ubicacion', (
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
        .select('id, sku, name, minimum_sale_quantity, units_per_presentation')
        .eq('is_active', true)
        .like('sku', 'E2E-%')
        .order('created_at', ascending: false)
        .limit(20);
    final warehouses = await client
        .from('warehouses')
        .select('id, code, name, is_default')
        .eq('is_active', true)
        .order('is_default', ascending: false);
    final locations = await client
        .from('inventory_locations')
        .select(
          'id, warehouse_id, code, name, is_active, is_default, stock_role',
        )
        .eq('is_active', true);
    if (customers.isEmpty || products.isEmpty || warehouses.isEmpty) {
      throw StateError(
        'E2E de Pedidos requiere clientes y productos E2E activos, y una '
        'bodega activa en Supabase local.',
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
    Map<String, dynamic>? selectedProduct;
    Map<String, dynamic>? selectedWarehouse;
    Map<String, dynamic>? selectedLocation;
    var quantityToDispatch = 0;
    var stockBefore = 0;

    for (final product in products) {
      final factor = product['units_per_presentation'] as int? ?? 1;
      final minimum = product['minimum_sale_quantity'] as int? ?? 1;
      final minimumQuantity = minimum < factor ? factor : minimum;
      final requiredQuantity =
          ((minimumQuantity + factor - 1) ~/ factor) * factor;
      for (final warehouse in warehouses) {
        final warehouseLocations = locations.where(
          (location) =>
              location['warehouse_id'] == warehouse['id'] &&
              location['stock_role'] == 'SELLABLE',
        );
        for (final location in warehouseLocations) {
          final available = balances
              .where(
                (balance) =>
                    balance['product_id'] == product['id'] &&
                    balance['warehouse_id'] == warehouse['id'] &&
                    balance['location_id'] == location['id'],
              )
              .fold<int>(
                0,
                (sum, balance) =>
                    sum +
                    ((balance['quantity'] as int) -
                        (balance['reserved_quantity'] as int)),
              );
          selectedProduct = product;
          selectedWarehouse = warehouse;
          selectedLocation = location;
          quantityToDispatch = requiredQuantity;
          stockBefore = available;
          break;
        }
        if (selectedProduct != null) break;
      }
      if (selectedProduct != null) break;
    }
    if (selectedProduct == null ||
        selectedWarehouse == null ||
        selectedLocation == null) {
      throw StateError(
        'E2E de Pedidos requiere productos, bodegas y ubicaciones activas.',
      );
    }

    final customer = customers.first;
    final displayName = customer['display_name'] as String?;
    final customerOption = displayName?.trim().isNotEmpty == true
        ? '${displayName!.trim()} · ${customer['name']}'
        : customer['name'] as String;
    final productLabel =
        '${selectedProduct['sku']} · ${selectedProduct['name']}';
    final locationLabel =
        '${selectedLocation['code']} · ${selectedLocation['name']}';
    final marker = const Uuid().v4().substring(0, 8);
    final notes = 'E2E pedido $marker';
    final adjustmentReference = 'E2E-PED-STOCK-$marker';

    if (stockBefore < quantityToDispatch) {
      await tester.tap(find.text('Inventario').first);
      await tester.pumpAndSettle();
      final movementsLink = find.text('Movimientos').first;
      await _ensureCentered(tester, movementsLink);
      await tester.tap(movementsLink);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo documento').first);
      await tester.pumpAndSettle();
      await _enterField(
        tester,
        'Referencia externa opcional',
        adjustmentReference,
      );
      await _enterField(tester, 'Motivo u observaciones', notes);
      await _selectDropdown(
        tester,
        'Bodega',
        '${selectedWarehouse['code']} · ${selectedWarehouse['name']}',
      );
      await _selectDropdown(tester, 'Ubicación', locationLabel);
      final productSearch = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Producto',
      );
      await tester.enterText(productSearch, selectedProduct['sku'] as String);
      await tester.pumpAndSettle();
      await tester.tap(find.text(productLabel).last);
      await tester.pumpAndSettle();
      final adjustmentLine = find.byWidgetPredicate(
        (widget) =>
            widget is InputDecorator &&
            widget.decoration.labelText == 'Cantidad',
      );
      final adjustmentQuantity = find.descendant(
        of: adjustmentLine,
        matching: find.byType(EditableText),
      );
      await tester.enterText(
        adjustmentQuantity,
        '${quantityToDispatch - stockBefore}',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar ajuste'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      stockBefore = quantityToDispatch;
    }

    await tester.tap(find.widgetWithText(ExpansionTile, 'Ventas'));
    await tester.pumpAndSettle();
    final ordersLink = find.text('Pedidos').last;
    await _ensureCentered(tester, ordersLink);
    await tester.tap(ordersLink);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo pedido'));
    await tester.pumpAndSettle();

    await _selectDropdown(tester, 'Cliente *', customerOption);
    await _selectDropdown(tester, 'Agregar producto', productLabel);
    await tester.tap(find.byTooltip('Agregar producto a las líneas'));
    await tester.pumpAndSettle();
    await _selectDropdown(
      tester,
      'Bodega de salida *',
      selectedWarehouse['name'] as String,
    );
    await _selectDropdown(tester, 'Ubicación de salida *', locationLabel);
    await _enterField(tester, 'Notas', notes);
    final createButton = find.text('Guardar documento');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final order = await client
        .from('sales_orders')
        .select(
          'id, order_number, customer_id, customer_name, status, notes, total_amount, inventory_document_id',
        )
        .eq('notes', notes)
        .single();
    expect(order['customer_id'], customer['id']);
    expect(
      order['customer_name'],
      displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : customer['name'],
    );
    expect(order['status'], 'CONFIRMED');
    expect(order['inventory_document_id'], isNotNull);
    expect(order['total_amount'], greaterThan(0));

    final orderLines = await client
        .from('sales_order_lines')
        .select('product_id, quantity, unit_price, product_sku, product_name')
        .eq('order_id', order['id'] as String);
    expect(orderLines, hasLength(1));
    expect(orderLines.single['product_id'], selectedProduct['id']);
    expect(orderLines.single['quantity'], quantityToDispatch);

    final inventoryDocument = await client
        .from('inventory_documents')
        .select(
          'document_type, status, origin_warehouse_id, origin_location_id',
        )
        .eq('id', order['inventory_document_id'] as String)
        .single();
    expect(inventoryDocument['document_type'], 'SALE_DISPATCH');
    expect(inventoryDocument['status'], 'CONFIRMED');
    expect(inventoryDocument['origin_warehouse_id'], selectedWarehouse['id']);
    expect(inventoryDocument['origin_location_id'], selectedLocation['id']);

    final saleMovements = await client
        .from('inventory_transactions')
        .select('quantity, warehouse_id, location_id, reason')
        .eq('document_id', order['inventory_document_id'] as String)
        .eq('reason', 'SALE');
    expect(
      saleMovements.fold<int>(
        0,
        (sum, movement) => sum + (movement['quantity'] as int),
      ),
      -quantityToDispatch,
    );
    expect(saleMovements.single['location_id'], selectedLocation['id']);

    final balanceAfter = await client
        .from('inventory_balances')
        .select('quantity, reserved_quantity')
        .eq('product_id', selectedProduct['id'] as String)
        .eq('warehouse_id', selectedWarehouse['id'] as String)
        .eq('location_id', selectedLocation['id'] as String)
        .single();
    expect(
      (balanceAfter['quantity'] as int) -
          (balanceAfter['reserved_quantity'] as int),
      stockBefore - quantityToDispatch,
    );

    expect(find.text('Pedidos'), findsWidgets);
    expect(find.text(order['order_number'] as String), findsWidgets);
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
  final optionFinder = find.text(option);
  expect(
    optionFinder,
    findsWidgets,
    reason: 'No aparece opción "$option" para "$label".',
  );
  await _ensureCentered(tester, optionFinder.last);
  await tester.tap(optionFinder.last);
  await tester.pumpAndSettle();
}

Future<void> _ensureCentered(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(
    tester.element(finder),
    alignment: 0.5,
  );
  await tester.pump();
}
