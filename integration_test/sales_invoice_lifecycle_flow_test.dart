import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:serp/core/configuration/app_configuration.dart';
import 'package:serp/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crear factura confirma inventario y abre perfil contextual', (
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
    final client = Supabase.instance.client;
    await client.auth.signOut();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final email = 'e2e-fixture@example.test';
    final password = 'E2e-Password123!';

    try {
      final adminClient = SupabaseClient(
        configuration.supabaseUrl,
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU',
      );
      await adminClient.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: password,
          emailConfirm: true,
        ),
      );
    } on AuthException catch (e) {
      if (e.statusCode != '422' && e.message != 'User already exists') {
        rethrow;
      }
    }

    final textFields = find.byType(TextFormField);
    expect(textFields, findsWidgets, reason: 'Debería haber campos de texto en el login');
    await tester.enterText(textFields.first, email);
    await tester.enterText(textFields.last, password);
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar Sesión'));

    var loginTries = 50;
    while (find.text('Ventas').evaluate().isEmpty && loginTries-- > 0) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    if (find.text('Iniciar Sesión').evaluate().isNotEmpty) {
      final snackbars = find.byType(SnackBar).evaluate();
      throw StateError('Login failed or redirect stuck. SnackBars: ${snackbars.length}. AuthState: ${client.auth.currentUser != null}');
    } else if (find.text('Ventas').evaluate().isEmpty) {
      throw StateError('Redirected but Ventas not found. Found text: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}');
    }

    await tester.pumpAndSettle();

    // -------------------------------------------------------------------------
    // APROVISIONAMIENTO DE FIXTURES (SELF-HEALING)
    // -------------------------------------------------------------------------
    // Nos aseguramos programáticamente de que siempre exista un producto y un
    // cliente E2E con inventario antes de hacer la prueba.
    // Usamos el service_role (adminClient) para esquivar políticas RLS 
    // en tablas de solo-lectura para vendedores (como products o warehouses).
    final uniqueId = const Uuid().v4().substring(0, 8).toUpperCase();
    
    // adminClient ya fue instanciado arriba
    final adminClient = SupabaseClient(
      configuration.supabaseUrl,
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU',
    );

    final existingCustomers = await adminClient.from('customers').select('id').like('name', 'Cliente E2E %').limit(1);
    if (existingCustomers.isEmpty) {
      await adminClient.from('customers').insert({
        'name': 'Cliente E2E $uniqueId',
        'tax_id': 'E2E$uniqueId',
        'is_active': true,
      });
    }

    final category = (await adminClient.from('categories').select('id').limit(1)).first;
    final presentation = (await adminClient.from('packaging_presentations').select('id').limit(1)).first;
    final productId = const Uuid().v4();
    
    await adminClient.from('products').insert({
      'id': productId,
      'sku': 'E2E-$uniqueId',
      'name': 'Producto E2E $uniqueId',
      'category_id': category['id'],
      'packaging_presentation_id': presentation['id'],
      'is_active': true,
      'minimum_sale_quantity': 1,
      'units_per_presentation': 1,
      'factory_cost': 10.0,
      'package_price': 15.0,
      'unit_price': 15.0,
      'cbm_per_moq': 0.1,
    });

    final defaultWarehouse = (await adminClient.from('warehouses').select('id').eq('is_active', true).order('is_default', ascending: false).limit(1)).first;
    final sellableLocation = (await adminClient.from('inventory_locations').select('id').eq('warehouse_id', defaultWarehouse['id']).eq('stock_role', 'SELLABLE').limit(1)).first;

    await adminClient.from('inventory_balances').upsert({
      'product_id': productId,
      'warehouse_id': defaultWarehouse['id'],
      'location_id': sellableLocation['id'],
      'quantity': 100,
      'reserved_quantity': 0,
    });
    // -------------------------------------------------------------------------

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
        .select('id, name, is_default')
        .eq('is_active', true)
        .order('is_default', ascending: false);
    final locations = await client
        .from('inventory_locations')
        .select('id, warehouse_id, is_active, stock_role')
        .eq('is_active', true);
    if (customers.isEmpty || products.isEmpty || warehouses.isEmpty) {
      throw StateError(
        'E2E de Facturas requiere clientes y productos E2E activos, y una '
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
    final sellableLocationIds = locations
        .where((row) => row['stock_role'] == 'SELLABLE')
        .map((row) => row['id'] as String)
        .toSet();
    Map<String, dynamic>? selectedProduct;
    Map<String, dynamic>? selectedWarehouse;
    var quantityToSell = 0;
    var stockBefore = 0;

    for (final product in products) {
      final factor = product['units_per_presentation'] as int? ?? 1;
      final minimum = product['minimum_sale_quantity'] as int? ?? 1;
      final minimumQuantity = minimum < factor ? factor : minimum;
      final requiredQuantity =
          ((minimumQuantity + factor - 1) ~/ factor) * factor;
      for (final warehouse in warehouses) {
        final activeWarehouseLocationIds = locations
            .where(
              (location) =>
                  location['warehouse_id'] == warehouse['id'] &&
                  sellableLocationIds.contains(location['id']),
            )
            .map((location) => location['id'] as String)
            .toSet();
        final available = balances
            .where(
              (balance) =>
                  balance['product_id'] == product['id'] &&
                  balance['warehouse_id'] == warehouse['id'] &&
                  activeWarehouseLocationIds.contains(balance['location_id']),
            )
            .fold<int>(
              0,
              (sum, balance) =>
                  sum +
                  ((balance['quantity'] as int) -
                      (balance['reserved_quantity'] as int)),
            );
        if (available >= requiredQuantity) {
          selectedProduct = product;
          selectedWarehouse = warehouse;
          quantityToSell = requiredQuantity;
          stockBefore = available;
          break;
        }
      }
      if (selectedProduct != null) break;
    }
    if (selectedProduct == null || selectedWarehouse == null) {
      throw StateError(
        'E2E de Facturas requiere un producto E2E con existencia vendible '
        'igual o mayor a su unidad minima en una bodega activa.',
      );
    }

    final customer = customers.first;
    final customerDisplay = customer['display_name'] as String?;
    final customerOption = customerDisplay?.trim().isNotEmpty == true
        ? '${customerDisplay!.trim()} · ${customer['name']}'
        : customer['name'] as String;
    final productLabel =
        '${selectedProduct['sku']} · ${selectedProduct['name']}';
    final marker = const Uuid().v4().substring(0, 8);
    final notes = 'E2E factura $marker';

    await tester.tap(find.widgetWithText(ExpansionTile, 'Ventas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Facturas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva factura'));
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
    await _enterField(tester, 'Notas', notes);
    final createButton = find.text('Guardar documento');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final invoice = await client
        .from('sales_invoices')
        .select(
          'id, invoice_number, customer_id, customer_name, status, notes, total_amount, inventory_document_id',
        )
        .eq('notes', notes)
        .single();
    expect(invoice['customer_id'], customer['id']);
    expect(invoice['status'], 'CONFIRMED');
    expect(invoice['inventory_document_id'], isNotNull);
    expect(invoice['total_amount'], greaterThan(0));

    final invoiceLines = await client
        .from('sales_invoice_lines')
        .select(
          'product_id, quantity, unit_price, total_price, product_sku, product_name',
        )
        .eq('invoice_id', invoice['id'] as String);
    expect(invoiceLines, hasLength(1));
    expect(invoiceLines.single['product_id'], selectedProduct['id']);
    expect(invoiceLines.single['quantity'], quantityToSell);

    final inventoryDocument = await client
        .from('inventory_documents')
        .select(
          'id, document_type, status, origin_warehouse_id, origin_location_id',
        )
        .eq('id', invoice['inventory_document_id'] as String)
        .single();
    expect(inventoryDocument['document_type'], 'SALE_DISPATCH');
    expect(inventoryDocument['status'], 'CONFIRMED');
    expect(inventoryDocument['origin_warehouse_id'], selectedWarehouse['id']);
    expect(inventoryDocument['origin_location_id'], isNull);

    final saleMovements = await client
        .from('inventory_transactions')
        .select('quantity, warehouse_id, location_id, reason')
        .eq('document_id', inventoryDocument['id'] as String)
        .eq('reason', 'SALE');
    expect(
      saleMovements.fold<int>(
        0,
        (sum, movement) => sum + (movement['quantity'] as int),
      ),
      -quantityToSell,
    );
    expect(
      saleMovements.every(
        (movement) => movement['warehouse_id'] == selectedWarehouse!['id'],
      ),
      isTrue,
    );

    final balancesAfter = await client
        .from('inventory_balances')
        .select(
          'product_id, warehouse_id, location_id, quantity, reserved_quantity',
        )
        .eq('product_id', selectedProduct['id'] as String)
        .eq('warehouse_id', selectedWarehouse['id'] as String);
    final activeLocationIds = locations
        .where(
          (location) =>
              location['warehouse_id'] == selectedWarehouse!['id'] &&
              sellableLocationIds.contains(location['id']),
        )
        .map((location) => location['id'] as String)
        .toSet();
    final stockAfter = balancesAfter
        .where((balance) => activeLocationIds.contains(balance['location_id']))
        .fold<int>(
          0,
          (sum, balance) =>
              sum +
              ((balance['quantity'] as int) -
                  (balance['reserved_quantity'] as int)),
        );
    expect(stockAfter, stockBefore - quantityToSell);

    expect(find.text('Facturas de Venta'), findsOneWidget);
    await tester.tap(find.text(invoice['invoice_number'] as String));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de factura'), findsOneWidget);
    expect(find.text(invoice['invoice_number'] as String), findsWidgets);
    await tester.tap(find.text('Ver perfil del cliente'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil de cliente'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver al documento'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de factura'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a facturas'));
    await tester.pumpAndSettle();
    expect(find.text('Facturas de Venta'), findsOneWidget);
    expect(find.text(invoice['invoice_number'] as String), findsWidgets);
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
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}
