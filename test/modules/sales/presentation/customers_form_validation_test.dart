import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/sales/api/customer_api.dart';
import 'package:serp/modules/sales/presentation/pages/customers_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cliente sin nombre exige correccion antes de guardar', (
    tester,
  ) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [customerApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: CustomersPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Escriba el nombre del negocio.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(api.createdCustomers, 0);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre del negocio'),
      'Cliente Test',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdCustomers, 1);
  });

  testWidgets('cliente con contacto sin nombre muestra error', (tester) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [customerApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: CustomersPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre del negocio'),
      'Cliente Test',
    );
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Agregar'));
    await tester.tap(find.widgetWithText(TextButton, 'Agregar'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    // El diálogo debe seguir abierto (no se guardó)
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(api.createdCustomers, 0);
    expect(find.text('Cada contacto necesita un nombre.'), findsOneWidget);
  });

  testWidgets('cliente rechaza limite de credito no numerico', (tester) async {
    final api = _RecordingCustomerApi();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [customerApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: CustomersPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo cliente'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre del negocio'),
      'Cliente Test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Límite de crédito'),
      'abc',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingrese un número válido.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(api.createdCustomers, 0);
  });

  testWidgets('cliente existente carga, actualiza contactos y desactiva', (
    tester,
  ) async {
    final api = _RecordingCustomerApi(
      initialCustomers: const [
        Customer(
          id: 'customer-1',
          name: 'Cliente Actual',
          phone: '1111',
          email: 'actual@example.com',
          province: 'San José',
          gira: 'Gira Central',
          creditLimit: 25,
          isActive: true,
        ),
      ],
      initialContacts: const [
        CustomerContact(
          id: 'contact-1',
          customerId: 'customer-1',
          name: 'Comprador',
          phone: '2222',
          role: 'Compras',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [customerApiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: CustomersPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cliente Actual'));
    await tester.pumpAndSettle();
    expect(find.text('Editar cliente'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Cliente Actual'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Comprador'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre del negocio'),
      'Cliente Actualizado',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Límite de crédito'),
      '125.50',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.updatedCustomerId, 'customer-1');
    expect(api.updatedCustomerName, 'Cliente Actualizado');
    expect(api.updatedCreditLimit, 125.50);
    expect(api.savedContactIds, contains('contact-1'));

    await tester.tap(find.text('Cliente Actual'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Desactivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(api.deactivatedCustomerId, 'customer-1');
  });
}

class _RecordingCustomerApi implements CustomerApi {
  _RecordingCustomerApi({
    this.initialCustomers = const [],
    this.initialContacts = const [],
  });

  final List<Customer> initialCustomers;
  final List<CustomerContact> initialContacts;
  int createdCustomers = 0;
  String? updatedCustomerId;
  String? updatedCustomerName;
  double? updatedCreditLimit;
  String? deactivatedCustomerId;
  final savedContactIds = <String?>[];

  @override
  Future<List<Customer>> getCustomers() async => initialCustomers;

  @override
  Future<Customer?> getCustomerById(String id) async => null;

  @override
  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
    String? province,
    String? gira,
  }) async {
    createdCustomers++;
    return Customer(
      id: 'customer-new',
      name: name,
      phone: phone,
      email: email,
      address: address,
      taxId: taxId,
      province: province,
      gira: gira,
      creditLimit: creditLimit ?? 0,
    );
  }

  @override
  Future<Customer> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
    String? province,
    String? gira,
  }) async {
    updatedCustomerId = id;
    updatedCustomerName = name;
    updatedCreditLimit = creditLimit;
    return Customer(
      id: id,
      name: name,
      phone: phone,
      email: email,
      address: address,
      taxId: taxId,
      province: province,
      gira: gira,
      creditLimit: creditLimit ?? 0,
    );
  }

  @override
  Future<void> deactivateCustomer(String id) async {
    deactivatedCustomerId = id;
  }

  @override
  Future<List<CustomerContact>> getCustomerContacts(String customerId) async =>
      initialContacts
          .where((contact) => contact.customerId == customerId)
          .toList();

  @override
  Future<CustomerContact> saveCustomerContact({
    String? id,
    required String customerId,
    required String name,
    String? phone,
    String? role,
  }) async {
    savedContactIds.add(id);
    return CustomerContact(
      id: id ?? 'contact-new',
      customerId: customerId,
      name: name,
      phone: phone,
      role: role,
    );
  }

  @override
  Future<void> deleteCustomerContact(String id) async {}

  @override
  Future<List<ProductBuyer>> getProductBuyers(String productId) async =>
      const [];
}
