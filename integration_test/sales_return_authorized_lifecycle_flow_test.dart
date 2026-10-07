import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:serp/core/configuration/app_configuration.dart';
import 'package:serp/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('usuario autenticado confirma devolucion y recibe inventario', (
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
        .select('id, invoice_number, status, customer_id, notes')
        .inFilter('status', ['CONFIRMED', 'PAID'])
        .like('notes', 'E2E factura %')
        .order('created_at', ascending: false)
        .limit(50);

    Map<String, dynamic>? invoice;
    Map<String, dynamic>? invoiceLine;
    for (final candidate in candidates) {
      final returns = await client
          .from('sales_returns')
          .select('id')
          .eq('invoice_id', candidate['id'] as String);
      if (returns.isNotEmpty) continue;
      final lines = await client
          .from('sales_invoice_lines')
          .select(
            'id, product_id, quantity, product_name, product_sku, total_price',
          )
          .eq('invoice_id', candidate['id'] as String)
          .limit(1);
      if (lines.isNotEmpty) {
        invoice = candidate;
        invoiceLine = lines.first;
        break;
      }
    }
    if (invoice == null || invoiceLine == null) {
      throw StateError(
        'Ejecuta sales_invoice_lifecycle_flow_test.dart para crear una factura E2E elegible.',
      );
    }

    final sellableLocations = await client
        .from('inventory_locations')
        .select('id')
        .eq('is_active', true)
        .eq('stock_role', 'SELLABLE');
    if (sellableLocations.isEmpty) {
      throw StateError('La devolución requiere un destino vendible activo.');
    }
    final beforeBalances = await client
        .from('inventory_balances')
        .select('location_id, quantity')
        .eq('product_id', invoiceLine['product_id'] as String);
    final quantitiesBefore = {
      for (final balance in beforeBalances)
        balance['location_id'] as String: balance['quantity'] as int,
    };

    final marker = const Uuid().v4();
    final email = 'e2e-fixture@example.test';
    final password = 'E2e-Password123!';

    try {
      final adminClient = SupabaseClient(
        AppConfiguration.local().supabaseUrl,
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

    // Sign out to ensure we are at the login page
    await client.auth.signOut();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final textFields = find.byType(TextFormField);
    expect(textFields, findsWidgets, reason: 'Debería haber campos de texto en el login');
    await tester.enterText(textFields.first, email);
    await tester.enterText(textFields.last, password);
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar Sesión'));

    var loginTries = 50;
    while (find.text('Ventas').evaluate().isEmpty && loginTries-- > 0) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(client.auth.currentUser, isNotNull);
    expect(client.auth.currentUser!.isAnonymous, isFalse);
    addTearDown(client.auth.signOut);

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
    final reason = 'Devolucion E2E autorizada $marker';
    final reasonField = find.widgetWithText(
      TextFormField,
      'Motivo de devolución *',
    );
    await _ensureCentered(tester, reasonField);
    await tester.enterText(reasonField, reason);

    final productName =
        invoiceLine['product_name'] as String? ??
        invoiceLine['product_sku'] as String;
    final productOption = find.text(productName).last;
    await _ensureCentered(tester, productOption);
    await tester.tap(productOption);
    await tester.pumpAndSettle();
    final confirm = find.text('Confirmar devolución');
    await _ensureCentered(tester, confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Detalle de devolución'), findsOneWidget);
    final returned = await client
        .from('sales_returns')
        .select(
          'id, return_number, status, invoice_id, customer_id, total_amount, '
          'inventory_document_id, reason, debt_reduction_amount, '
          'financial_resolution_amount',
        )
        .eq('invoice_id', invoice['id'] as String)
        .single();
    expect(returned['status'], 'CONFIRMED');
    expect(returned['reason'], reason);
    expect(returned['total_amount'], invoiceLine['total_price']);
    expect(returned['inventory_document_id'], isNotNull);

    final returnLines = await client
        .from('sales_return_lines')
        .select(
          'invoice_line_id, product_id, quantity, condition, inventory_location_id',
        )
        .eq('return_id', returned['id'] as String);
    expect(returnLines, hasLength(1));
    expect(returnLines.single['invoice_line_id'], invoiceLine['id']);
    expect(returnLines.single['product_id'], invoiceLine['product_id']);
    expect(returnLines.single['quantity'], invoiceLine['quantity']);
    expect(returnLines.single['condition'], 'GOOD');
    final destinationId = returnLines.single['inventory_location_id'] as String;
    expect(
      sellableLocations.any((location) => location['id'] == destinationId),
      isTrue,
    );

    final inventoryDocument = await client
        .from('inventory_documents')
        .select('document_type, status')
        .eq('id', returned['inventory_document_id'] as String)
        .single();
    expect(inventoryDocument['document_type'], 'CUSTOMER_RETURN');
    expect(inventoryDocument['status'], 'CONFIRMED');
    final movements = await client
        .from('inventory_transactions')
        .select('quantity, reason, location_id')
        .eq('document_id', returned['inventory_document_id'] as String);
    expect(movements, hasLength(1));
    expect(movements.single['quantity'], invoiceLine['quantity']);
    expect(movements.single['reason'], 'RETURN');
    expect(movements.single['location_id'], destinationId);

    final after = await client
        .from('inventory_balances')
        .select('quantity')
        .eq('product_id', invoiceLine['product_id'] as String)
        .eq('location_id', destinationId)
        .single();
    expect(
      after['quantity'],
      (quantitiesBefore[destinationId] ?? 0) + (invoiceLine['quantity'] as int),
    );
  });
}

Future<void> _ensureCentered(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
}
