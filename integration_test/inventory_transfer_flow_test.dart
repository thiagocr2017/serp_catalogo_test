import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:serp/core/configuration/app_configuration.dart';
import 'package:serp/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'un traslado conserva trazabilidad en borrador, despacho y recepción',
    (tester) async {
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
          .select('id, sku, name')
          .eq('is_active', true);
      final productById = {
        for (final product in products) product['id'] as String: product,
      };
      final locations = await client
          .from('inventory_locations')
          .select('id, code, name, warehouse_id, stock_role')
          .eq('is_active', true)
          .eq('stock_role', 'SELLABLE');
      final balances = await client
          .from('inventory_balances')
          .select('product_id, warehouse_id, location_id, quantity')
          .gt('quantity', 0);

      Map<String, dynamic>? sourceBalance;
      Map<String, dynamic>? origin;
      for (final balance in balances) {
        final productId = balance['product_id'] as String;
        if (!productById.containsKey(productId)) continue;
        final sourceLocations = locations.where(
          (location) => location['id'] == balance['location_id'],
        );
        if (sourceLocations.isEmpty) continue;
        sourceBalance = balance;
        origin = sourceLocations.first;
        break;
      }
      if (sourceBalance == null || origin == null) {
        throw StateError(
          'Se necesita un producto activo con saldo en una ubicacion '
          'vendible.',
        );
      }

      final warehouse = await client
          .from('warehouses')
          .select('id, code, name')
          .eq('id', sourceBalance['warehouse_id'] as String)
          .single();
      final warehouseId = warehouse['id'] as String;
      const destinationCode = 'E2E-TRANSFER-DEST';
      final existingDestinations = locations.where(
        (location) =>
            location['warehouse_id'] == warehouseId &&
            location['id'] != origin!['id'],
      );
      final destination = existingDestinations.isNotEmpty
          ? existingDestinations.first
          : await _ensureDestinationLocation(
              tester,
              client,
              warehouseId: warehouseId,
              warehouseLabel: '${warehouse['code']} · ${warehouse['name']}',
              code: destinationCode,
            );
      final product = productById[sourceBalance['product_id'] as String]!;
      final originBalance = sourceBalance['quantity'] as int;
      final originId = origin['id'] as String;
      final destinationId = destination['id'] as String;
      final destinationBalanceRow = balances.where(
        (balance) =>
            balance['product_id'] == product['id'] &&
            balance['location_id'] == destinationId,
      );
      final destinationBalance = destinationBalanceRow.isEmpty
          ? 0
          : destinationBalanceRow.first['quantity'] as int;
      final marker = 'E2E-TRANSFER-${const Uuid().v4()}';

      if (find.text('Movimientos').evaluate().isEmpty) {
        await tester.tap(find.text('Inventario').first);
        await tester.pumpAndSettle();
      }
      final movementsLink = find.text('Movimientos').first;
      await tester.ensureVisible(movementsLink);
      await tester.tap(movementsLink);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo documento').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Traslado').first);
      await tester.pumpAndSettle();
      final warehouseLabel = '${warehouse['code']} · ${warehouse['name']}';
      await _selectDropdown(tester, 'Bodega de origen', warehouseLabel);
      await _selectDropdown(tester, 'Bodega de destino', warehouseLabel);
      await _selectDropdown(
        tester,
        'Ubicación de origen',
        '${origin['code']} · ${origin['name']}',
      );
      await _selectDropdown(
        tester,
        'Ubicación de destino',
        '${destination['code']} · ${destination['name']}',
      );
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
      await _enterTextField(tester, 'Cantidad', '1');
      await tester.ensureVisible(find.text('Guardar como borrador'));
      await tester.tap(find.text('Guardar como borrador'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final document = await client
          .from('inventory_documents')
          .select('id, document_number, status, document_type')
          .eq('external_reference', marker)
          .single();
      final documentId = document['id'] as String;
      final documentNumber = document['document_number'] as String;
      expect(document['document_type'], 'TRANSFER');
      expect(document['status'], 'BORRADOR');
      expect(find.text(documentNumber), findsOneWidget);
      expect(
        await client
            .from('inventory_transactions')
            .select('id')
            .eq('document_id', documentId),
        isEmpty,
      );

      await tester.tap(find.byTooltip('Volver a documentos'));
      await tester.pumpAndSettle();
      expect(find.text('Documentos de inventario'), findsOneWidget);
      await _runDocumentAction(tester, documentNumber, 'Despachar traslado');

      var current = await _readDocument(client, documentId);
      expect(current['status'], 'DESPACHADA');
      var movements = await client
          .from('inventory_transactions')
          .select('quantity, reason, location_id')
          .eq('document_id', documentId);
      expect(movements, hasLength(1));
      expect(movements.single['quantity'], -1);
      expect(movements.single['reason'], 'TRANSFER_OUT');
      expect(movements.single['location_id'], originId);
      expect(
        await _balance(client, product['id'] as String, originId),
        originBalance - 1,
      );
      expect(
        await _balance(client, product['id'] as String, destinationId),
        destinationBalance,
      );

      await _runDocumentAction(tester, documentNumber, 'Marcar en tránsito');
      current = await _readDocument(client, documentId);
      expect(current['status'], 'EN_TRANSITO');

      await _runDocumentAction(tester, documentNumber, 'Registrar recepción');
      current = await _readDocument(client, documentId);
      expect(current['status'], 'RECIBIDA');
      movements = await client
          .from('inventory_transactions')
          .select('quantity, reason, location_id')
          .eq('document_id', documentId);
      expect(movements, hasLength(2));
      expect(
        movements.where((movement) => movement['reason'] == 'TRANSFER_IN'),
        hasLength(1),
      );
      final incoming = movements.singleWhere(
        (movement) => movement['reason'] == 'TRANSFER_IN',
      );
      expect(incoming['quantity'], 1);
      expect(incoming['location_id'], destinationId);
      expect(
        await _balance(client, product['id'] as String, destinationId),
        destinationBalance + 1,
      );
    },
  );
}

Future<Map<String, dynamic>> _ensureDestinationLocation(
  WidgetTester tester,
  SupabaseClient client, {
  required String warehouseId,
  required String warehouseLabel,
  required String code,
}) async {
  final existing = await client
      .from('inventory_locations')
      .select('id, code, name, warehouse_id, stock_role, is_active')
      .eq('warehouse_id', warehouseId)
      .eq('code', code)
      .maybeSingle();
  if (existing != null) {
    if (existing['is_active'] != true || existing['stock_role'] != 'SELLABLE') {
      throw StateError(
        'La ubicacion reservada para E2E existe pero no esta activa y '
        'vendible: $code.',
      );
    }
    return existing;
  }

  await tester.tap(find.text('Inventario').first);
  await tester.pumpAndSettle();
  final warehousesLink = find.text('Bodegas y ubicaciones').first;
  await tester.ensureVisible(warehousesLink);
  await tester.tap(warehousesLink);
  await tester.pumpAndSettle();
  final warehouseTile = find.ancestor(
    of: find.text(warehouseLabel),
    matching: find.byType(ExpansionTile),
  );
  final addLocation = find.descendant(
    of: warehouseTile,
    matching: find.byTooltip('Agregar ubicación'),
  );
  await tester.ensureVisible(addLocation);
  await tester.tap(addLocation);
  await tester.pumpAndSettle();
  await _enterTextField(tester, 'Código', code);
  await _enterTextField(tester, 'Nombre', 'Destino E2E de traslados');
  await tester.tap(find.text('Guardar').last);
  await tester.pumpAndSettle(const Duration(seconds: 2));

  return client
      .from('inventory_locations')
      .select('id, code, name, warehouse_id, stock_role, is_active')
      .eq('warehouse_id', warehouseId)
      .eq('code', code)
      .single();
}

Future<Map<String, dynamic>> _readDocument(SupabaseClient client, String id) =>
    client
        .from('inventory_documents')
        .select('id, status, document_type')
        .eq('id', id)
        .single();

Future<int> _balance(
  SupabaseClient client,
  String productId,
  String locationId,
) async {
  final row = await client
      .from('inventory_balances')
      .select('quantity')
      .eq('product_id', productId)
      .eq('location_id', locationId)
      .maybeSingle();
  return row == null ? 0 : row['quantity'] as int;
}

Future<void> _runDocumentAction(
  WidgetTester tester,
  String documentNumber,
  String action,
) async {
  final tile = find.ancestor(
    of: find.text(documentNumber),
    matching: find.byType(Card),
  );
  final button = find.descendant(of: tile, matching: find.text(action));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle(const Duration(seconds: 2));
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
  final optionFinder = find.text(option).last;
  await tester.ensureVisible(optionFinder);
  await tester.tap(optionFinder);
  await tester.pumpAndSettle();
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
