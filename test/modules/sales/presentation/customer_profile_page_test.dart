import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/configuration/configuration_module.dart';
import 'package:serp/modules/sales/api/customer_api.dart';
import 'package:serp/modules/sales/api/sales_routes.dart';
import 'package:serp/modules/sales/presentation/pages/customer_profile_page.dart';

void main() {
  testWidgets('perfil renderiza datos generales y contactos', (tester) async {
    final api = _FakeCustomerApi(
      customers: const [
        Customer(
          id: 'customer-1',
          name: 'Distribuidora Legal S.A.',
          displayName: 'La Legal',
          phone: '+506 2435-7658',
          email: 'facturas@example.com',
          address: 'San Jose centro',
          taxId: '3-101-123456',
          province: 'San Jose',
          gira: 'Central',
          customerType: 'CREDIT',
          creditDays: 30,
          creditLimit: 500,
          currentBalance: 120,
          documentPreference: 'ASK_EACH_TIME',
        ),
      ],
      contacts: const [
        CustomerContact(
          id: 'contact-1',
          customerId: 'customer-1',
          name: 'Andrea Compras',
          phone: '+506 8888-7777',
          role: 'Compras',
        ),
      ],
    );

    await tester.pumpWidget(_profileApp(api, 'customer-1'));
    await tester.pumpAndSettle();

    expect(find.text('La Legal'), findsOneWidget);
    expect(find.text('Distribuidora Legal S.A.'), findsOneWidget);
    expect(find.text('Cliente credito'), findsOneWidget);
    expect(find.text('Preguntar al facturar'), findsWidgets);
    expect(find.text('+506 2435-7658'), findsOneWidget);
    expect(find.text('Andrea Compras'), findsOneWidget);
    expect(find.textContaining('Compras'), findsWidgets);
    expect(find.text('Sin resumen de compras todavia'), findsOneWidget);
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Tipo de identificacion'), findsOneWidget);
    expect(find.text('Sin tipo'), findsOneWidget);
    expect(find.text('Actividad economica'), findsOneWidget);
    expect(find.text('Sin actividad'), findsOneWidget);
    expect(find.text('Factura electronica'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });

  testWidgets('perfil muestra los datos fiscales de factura electronica', (
    tester,
  ) async {
    final api = _FakeCustomerApi(
      customers: const [
        Customer(
          id: 'customer-1',
          name: 'Cliente FE Completo',
          requiresEInvoice: true,
          taxId: '3-101-123456',
          identificationTypeId: 'type-1',
          email: 'fe@example.com',
          address: 'Av. Central 1',
          economicActivity: 'Servicios',
        ),
      ],
      contacts: const [],
    );

    await tester.pumpWidget(_profileApp(api, 'customer-1'));
    await tester.pumpAndSettle();

    expect(find.text('Cedula juridica'), findsOneWidget);
    expect(find.text('Servicios'), findsOneWidget);
    expect(find.text('Si'), findsOneWidget);
  });

  testWidgets('perfil muestra alerta de cliente inactivo', (tester) async {
    final api = _FakeCustomerApi(
      customers: const [
        Customer(
          id: 'customer-1',
          name: 'Cliente Pausado',
          isActive: false,
          deactivationReason: 'Cierre temporal',
        ),
      ],
    );

    await tester.pumpWidget(_profileApp(api, 'customer-1'));
    await tester.pumpAndSettle();

    expect(find.text('Cliente inactivo'), findsOneWidget);
    expect(find.text('Cierre temporal'), findsOneWidget);
  });

  testWidgets('lista navega al perfil del cliente', (tester) async {
    final api = _FakeCustomerApi(
      customers: const [
        Customer(
          id: 'customer-1',
          name: 'Distribuidora Legal S.A.',
          displayName: 'La Legal',
        ),
      ],
    );

    await tester.pumpWidget(_routesApp(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('La Legal · Distribuidora Legal S.A.'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerProfilePage), findsOneWidget);
    expect(find.text('Perfil de cliente'), findsOneWidget);
  });
}

Widget _profileApp(_FakeCustomerApi api, String customerId) => ProviderScope(
  overrides: [
    customerApiProvider.overrideWithValue(api),
    identificationTypeDtosProvider.overrideWith(
      (ref) async => const [
        IdentificationTypeDto(
          id: 'type-1',
          code: 'JURIDICAL_ID',
          name: 'Cedula juridica',
          isActive: true,
          version: 1,
        ),
      ],
    ),
  ],
  child: MaterialApp(home: CustomerProfilePage(customerId: customerId)),
);

Widget _routesApp(_FakeCustomerApi api) => ProviderScope(
  overrides: [customerApiProvider.overrideWithValue(api)],
  child: MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: '/sales/customers',
      routes: salesRoutes,
    ),
  ),
);

class _FakeCustomerApi implements CustomerApi {
  const _FakeCustomerApi({this.customers = const [], this.contacts = const []});

  final List<Customer> customers;
  final List<CustomerContact> contacts;

  @override
  Future<List<Customer>> getCustomers() async => customers;

  @override
  Future<Customer?> getCustomerById(String id) async =>
      customers.where((customer) => customer.id == id).firstOrNull;

  @override
  Future<List<CustomerContact>> getCustomerContacts(String customerId) async =>
      contacts.where((contact) => contact.customerId == customerId).toList();

  @override
  Future<Customer> createCustomer({
    required String name,
    String? displayName,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
    String countryCode = 'CR',
    String? province,
    String? city,
    String? gira,
    String? preferredCarrierId,
    String? identificationTypeId,
    String? economicActivity,
    String customerType = 'CASH',
    int? creditDays,
    String documentPreference = 'E_INVOICE',
    bool requiresEInvoice = false,
  }) async => throw UnimplementedError();

  @override
  Future<Customer> updateCustomer({
    required String id,
    required String name,
    String? displayName,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
    String countryCode = 'CR',
    String? province,
    String? city,
    String? gira,
    String? preferredCarrierId,
    String? identificationTypeId,
    String? economicActivity,
    String customerType = 'CASH',
    int? creditDays,
    String documentPreference = 'E_INVOICE',
    bool requiresEInvoice = false,
  }) async => throw UnimplementedError();

  @override
  Future<void> deactivateCustomer(String id, {String? reason}) async {}

  @override
  Future<CustomerContact> saveCustomerContact({
    String? id,
    required String customerId,
    required String name,
    String? phone,
    String? role,
    DateTime? birthday,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteCustomerContact(String id) async {}

  @override
  Future<List<CustomerEmail>> getCustomerEmails(String customerId) async =>
      const [];

  @override
  Future<CustomerEmail> saveCustomerEmail({
    String? id,
    required String customerId,
    required String email,
    CustomerEmailPurpose purpose = CustomerEmailPurpose.copy,
    String? label,
    bool isActive = true,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteCustomerEmail(String id) async {}

  @override
  Future<List<ProductBuyer>> getProductBuyers(String productId) async =>
      const [];
}
