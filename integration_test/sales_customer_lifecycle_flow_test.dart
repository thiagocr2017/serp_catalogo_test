import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:serp/core/configuration/app_configuration.dart';
import 'package:serp/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('crear, encontrar y editar cliente conserva sus datos', (
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
    final uuid = const Uuid().v4();
    final marker = uuid.replaceAll('-', '').substring(0, 8);
    final originalName = 'Cliente E2E $marker';
    final displayName = 'Comercial E2E $marker';
    final editedDisplayName = 'Comercial editado E2E $marker';
    final phoneDigits = uuid.replaceAll(RegExp(r'[^0-9]'), '');
    final localPhone = '8${phoneDigits.substring(0, 7)}';

    await tester.tap(find.widgetWithText(ExpansionTile, 'Ventas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clientes').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    await _enterField(tester, 'customerDisplayNameField', displayName);
    await _enterField(tester, 'customerNameField', originalName);
    await _enterField(tester, 'customerPhoneField', localPhone);
    await _enterField(tester, 'customerAddressField', 'Direccion E2E $marker');
    await _enterField(tester, 'customerGiraField', 'Gira E2E $marker');
    final saveButton = find.text('Guardar').last;
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final created = await client
        .from('customers')
        .select('id, name, display_name, phone, address, gira, is_active')
        .eq('name', originalName)
        .single();
    final customerId = created['id'] as String;
    expect(created['display_name'], displayName);
    expect(created['address'], 'Direccion E2E $marker');
    expect(created['gira'], 'Gira E2E $marker');
    expect(created['is_active'], isTrue);
    expect(find.text('Perfil de cliente'), findsOneWidget);
    expect(find.text(displayName), findsWidgets);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await _enterField(tester, 'customerDisplayNameField', editedDisplayName);
    final updateButton = find.text('Guardar').last;
    await tester.ensureVisible(updateButton);
    await tester.tap(updateButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final persisted = await client
        .from('customers')
        .select('id, name, display_name, phone, address, gira, is_active')
        .eq('id', customerId)
        .single();
    expect(persisted['name'], originalName);
    expect(persisted['display_name'], editedDisplayName);
    expect(
      (persisted['phone'] as String).replaceAll(RegExp(r'\D'), ''),
      contains('506$localPhone'),
    );
    expect(persisted['address'], 'Direccion E2E $marker');
    expect(persisted['gira'], 'Gira E2E $marker');
    expect(persisted['is_active'], isTrue);
    expect(find.text(editedDisplayName), findsWidgets);
  });
}

Future<void> _enterField(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}
