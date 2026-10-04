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

  testWidgets(
    'perfil muestra alertas de credito vencido y documentos pendientes',
    (tester) async {
      final api = _FakeCustomerApi(
        customers: const [
          Customer(
            id: 'customer-1',
            name: 'Cliente Con Alertas',
            customerType: 'CREDIT',
            creditLimit: 500,
            currentBalance: 200,
          ),
        ],
        summary: const CustomerCommercialSummaryDto(
          customerId: 'customer-1',
          overdueInvoicesCount: 2,
          overdueInvoicesAmount: 150.0,
          totalPendingDocuments: 3,
        ),
      );

      await tester.pumpWidget(_profileApp(api, 'customer-1'));
      await tester.pumpAndSettle();

      expect(find.text('Credito vencido'), findsOneWidget);
      expect(
        find.text('2 factura(s) vencida(s) por un total de 150.00.'),
        findsOneWidget,
      );
      expect(find.text('Documentos pendientes'), findsOneWidget);
      expect(
        find.text(
          '3 documento(s) pendientes de procesar, despachar o liquidar.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'perfil muestra ultima compra y productos frecuentes cuando existen',
    (tester) async {
      final api = _FakeCustomerApi(
        customers: const [
          Customer(
            id: 'customer-1',
            name: 'Cliente Con Historial',
          ),
        ],
        summary: CustomerCommercialSummaryDto(
          customerId: 'customer-1',
          lastPurchaseAt: DateTime(2026, 9, 15),
          totalInvoiced: 1250.0,
          frequentProducts: const [
            FrequentProductDto(
              productId: 'prod-1',
              productName: 'Jabón Líquido 1L',
              productSku: 'JAB-001',
              totalQuantity: 24,
              purchaseCount: 3,
            ),
          ],
        ),
      );

      await tester.pumpWidget(_profileApp(api, 'customer-1'));
      await tester.pumpAndSettle();

      expect(find.text('2026-09-15'), findsWidgets);
      expect(find.text('Total facturado'), findsOneWidget);
      expect(find.text('1250.00'), findsOneWidget);
      expect(find.text('Productos frecuentes'), findsOneWidget);
      expect(find.text('Jabón Líquido 1L'), findsOneWidget);
      expect(
        find.text('24 unidades compradas en 3 documento(s)'),
        findsOneWidget,
      );
    },
  );

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

  testWidgets(
    'perfil muestra politica de envio, categorias y rankings comerciales',
    (tester) async {
      const customer = Customer(
        id: 'cust-comercial',
        name: 'Distribuidora Mayorista S.A.',
        shippingPaymentPolicy: 'PREPAID',
        categoryNames: ['Mayorista', 'Corporativo'],
      );
      final summary = CustomerCommercialSummaryDto(
        customerId: 'cust-comercial',
        commercialRankings: const ['Mayor Facturación', 'Compra Recurrente'],
      );
      final api = _FakeCustomerApi(
        customers: const [customer],
        summary: summary,
      );

      await tester.pumpWidget(_profileApp(api, 'cust-comercial'));
      await tester.pumpAndSettle();

      expect(find.text('Pagado antes del envío'), findsOneWidget);
      expect(find.text('Mayorista'), findsOneWidget);
      expect(find.text('Corporativo'), findsOneWidget);
      expect(find.text('Mayor Facturación'), findsOneWidget);
      expect(find.text('Compra Recurrente'), findsOneWidget);
    },
  );
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
  const _FakeCustomerApi({
    this.customers = const [],
    this.contacts = const [],
    this.summary,
  });

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
    String shippingPaymentPolicy = 'INCLUDED',
    List<String> categoryIds = const [],
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
    String shippingPaymentPolicy = 'INCLUDED',
    List<String>? categoryIds,
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

  @override
  Future<CustomerCommercialSummaryDto> getCustomerCommercialSummary(
    String customerId,
  ) async =>
      summary ?? CustomerCommercialSummaryDto.empty(customerId);

  @override
  Future<List<CustomerCategoryDto>> getCustomerCategories() async => const [];

  final CustomerCommercialSummaryDto? summary;
}
