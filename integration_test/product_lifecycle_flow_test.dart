import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:serp/core/configuration/app_configuration.dart';
import 'package:serp/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crear, buscar y editar producto conserva su stock', (
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
    final categories = await client
        .from('categories')
        .select('id, name')
        .eq('is_active', true)
        .limit(1);
    final presentations = await client
        .from('packaging_presentations')
        .select('id, name')
        .eq('is_active', true)
        .limit(1);
    if (categories.isEmpty || presentations.isEmpty) {
      throw StateError(
        'E2E de Productos requiere al menos una categoria activa y una '
        'presentacion activa en la base local.',
      );
    }

    final marker = const Uuid().v4().substring(0, 8).toUpperCase();
    final sku = 'E2E-$marker';
    final originalName = 'Producto E2E $marker';
    final editedName = 'Producto E2E editado $marker';

    await tester.tap(find.text('Nuevo producto'));
    await tester.pumpAndSettle();
    await _enterField(tester, 'SKU', sku);
    await _enterField(tester, 'Nombre', originalName);
    await _enterField(tester, 'Precio unitario USD', '12.50');
    await _enterField(tester, 'Costo de fábrica USD', '4.00');
    await _enterField(tester, 'Stock inicial', '3');

    await _selectDropdown(
      tester,
      'Categoría',
      categories.first['name'] as String,
    );
    await _selectDropdown(
      tester,
      'Presentación de venta',
      presentations.first['name'] as String,
    );

    final createButton = find.text('Guardar producto');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await _enterSearch(tester, sku);
    final productCell = find.text(originalName).last;
    await tester.ensureVisible(productCell);
    await tester.tap(productCell);
    await tester.pumpAndSettle();
    expect(find.text('$sku · $originalName'), findsOneWidget);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await _enterField(tester, 'Nombre', editedName);
    final saveButton = find.text('Guardar producto');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final persistedProduct = await client
        .from('products')
        .select('id, sku, name, current_stock, unit_price, is_active')
        .eq('sku', sku)
        .single();
    expect(persistedProduct['name'], editedName);
    expect(persistedProduct['current_stock'], 3);
    expect(persistedProduct['unit_price'], 12.5);
    expect(persistedProduct['is_active'], isTrue);
    expect(find.text('$sku · $editedName'), findsOneWidget);

    final initialMovements = await client
        .from('inventory_transactions')
        .select('quantity, reason')
        .eq('product_id', persistedProduct['id'] as String)
        .eq('reason', 'INITIAL_STOCK');
    expect(initialMovements, hasLength(1));
    expect(initialMovements.single['quantity'], 3);
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
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == label,
  );
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  final menuOption = find.text(option).last;
  await tester.tap(menuOption);
  await tester.pumpAndSettle();
}

Future<void> _enterSearch(WidgetTester tester, String value) async {
  final search = find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.decoration?.hintText == 'Buscar por nombre, SKU o descripción',
  );
  await tester.ensureVisible(search);
  await tester.enterText(search, value);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}
