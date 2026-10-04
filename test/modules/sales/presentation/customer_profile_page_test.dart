import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/configuration/configuration_module.dart';
import 'package:serp/modules/sales/api/customer_api.dart';
import 'package:serp/modules/sales/api/sales_routes.dart';
import 'package:serp/modules/sales/presentation/pages/customer_profile_page.dart';
import 'package:serp/shared/widgets/desktop_shell_widget.dart';

void main() {
  testWidgets('perfil renderiza datos generales y contactos', (tester) async {
    final api = _FakeCustomerApi(
      customers: const [
        CustomerDto(
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
        CustomerContactDto(
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

  testWidgets('perfil vuelve a la lista de clientes', (tester) async {
    final api = _FakeCustomerApi(
      customers: const [
        CustomerDto(id: 'customer-1', name: 'Cliente de Prueba'),
      ],
    );

    await tester.pumpWidget(
      _shellRoutesApp(api, '/sales/customers/customer-1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Volver a clientes'), findsOneWidget);
    await tester.tap(find.text('Volver a clientes'));
    await tester.pumpAndSettle();

    expect(find.text('Mostrando 1 de 1 clientes'), findsOneWidget);
    expect(find.text('Cliente de Prueba'), findsOneWidget);
  });

  testWidgets('menu Clientes navega al indice desde el perfil', (tester) async {
    final api = _FakeCustomerApi(
      customers: const [
        CustomerDto(id: 'customer-1', name: 'Cliente de Prueba'),
      ],
    );

    await tester.pumpWidget(
      _shellRoutesApp(api, '/sales/customers/customer-1'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clientes'));
    await tester.pumpAndSettle();

    expect(find.text('Mostrando 1 de 1 clientes'), findsOneWidget);
    expect(find.text('Perfil de cliente'), findsNothing);
  });

  testWidgets('perfil muestra los datos fiscales de factura electronica', (
    tester,
  ) async {
    final api = _FakeCustomerApi(
      customers: const [
        CustomerDto(
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
        CustomerDto(
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
          CustomerDto(
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

  testWidgets('perfil ordena alertas financieras antes de otras alertas', (
    tester,
  ) async {
    final api = _FakeCustomerApi(
      customers: const [
        CustomerDto(
          id: 'customer-1',
          name: 'Cliente Riesgoso',
          isActive: false,
          deactivationReason: 'Revision comercial',
          customerType: 'CREDIT',
          creditLimit: 500,
          currentBalance: 500,
        ),
      ],
      summary: const CustomerCommercialSummaryDto(
        customerId: 'customer-1',
        overdueInvoicesCount: 1,
        overdueInvoicesAmount: 75.0,
        totalPendingDocuments: 2,
      ),
    );

    await tester.pumpWidget(_profileApp(api, 'customer-1'));
    await tester.pumpAndSettle();

    final alertTitles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => tile.title)
        .whereType<Text>()
        .map((title) => title.data)
        .whereType<String>()
        .where(
          {
            'Credito vencido',
            'Sobre limite de credito',
            'Cliente inactivo',
            'Documentos pendientes',
          }.contains,
        )
        .toList();

    expect(alertTitles, [
      'Credito vencido',
      'Sobre limite de credito',
      'Cliente inactivo',
      'Documentos pendientes',
    ]);
  });

  testWidgets(
    'perfil muestra ultima compra y productos frecuentes cuando existen',
    (tester) async {
      final api = _FakeCustomerApi(
        customers: const [
          CustomerDto(id: 'customer-1', name: 'Cliente Con Historial'),
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
        CustomerDto(
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
      const customer = CustomerDto(
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

  testWidgets('perfil muestra vacios especificos por pestana de documentos', (
    tester,
  ) async {
    final api = _FakeCustomerApi(
      customers: const [
        CustomerDto(id: 'customer-1', name: 'Cliente Sin Documentos'),
      ],
    );

    await tester.pumpWidget(_profileApp(api, 'customer-1'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Sin pedidos abiertos'), findsOneWidget);

    await tester.tap(find.text('Facturas'));
    await tester.pumpAndSettle();
    expect(find.text('Sin facturas'), findsOneWidget);

    await tester.tap(find.text('Pagos'));
    await tester.pumpAndSettle();
    expect(find.text('Sin pagos registrados'), findsOneWidget);
  });

  testWidgets('lista muestra resultados, filtros activos y limpiar filtros', (
    tester,
  ) async {
    final api = _FakeCustomerApi(
      customers: const [
        CustomerDto(id: 'customer-1', name: 'Distribuidora Legal S.A.'),
        CustomerDto(
          id: 'customer-2',
          name: 'Cliente Norte',
          province: 'Heredia',
        ),
      ],
    );

    await tester.pumpWidget(_routesApp(api));
    await tester.pumpAndSettle();

    expect(find.text('Mostrando 2 de 2 clientes'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('Mostrando 0 de 2 clientes'), findsOneWidget);
    expect(find.text('Sin resultados'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Limpiar filtros'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Limpiar filtros'));
    await tester.pumpAndSettle();

    expect(find.text('Mostrando 2 de 2 clientes'), findsOneWidget);
    expect(find.text('Distribuidora Legal S.A.'), findsOneWidget);
    expect(find.text('Cliente Norte'), findsOneWidget);
  });

  testWidgets('lista sin clientes muestra CTA para crear el primero', (
    tester,
  ) async {
    await tester.pumpWidget(_routesApp(const _FakeCustomerApi()));
    await tester.pumpAndSettle();

    expect(find.text('No hay clientes registrados'), findsOneWidget);
    expect(find.text('Crear primer cliente'), findsOneWidget);
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

Widget _shellRoutesApp(_FakeCustomerApi api, String initialLocation) =>
    ProviderScope(
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
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: initialLocation,
          routes: [
            ShellRoute(
              builder: (context, state, child) => DesktopShellWidget(
                currentLocation: state.uri.path,
                child: child,
              ),
              routes: salesRoutes,
            ),
          ],
        ),
      ),
    );

class _FakeCustomerApi implements CustomerApi {
  const _FakeCustomerApi({
    this.customers = const [],
    this.contacts = const [],
    this.summary,
  });

  final List<CustomerDto> customers;
  final List<CustomerContactDto> contacts;

  @override
  Future<List<CustomerDto>> getCustomers() async => customers;

  @override
  Future<CustomerDto?> getCustomerById(String id) async =>
      customers.where((customer) => customer.id == id).firstOrNull;

  @override
  Future<List<CustomerContactDto>> getCustomerContacts(
    String customerId,
  ) async =>
      contacts.where((contact) => contact.customerId == customerId).toList();

  @override
  Future<CustomerDto> createCustomer({
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
  Future<CustomerDto> updateCustomer({
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
  Future<CustomerContactDto> saveCustomerContact({
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
  Future<List<CustomerEmailDto>> getCustomerEmails(String customerId) async =>
      const [];

  @override
  Future<CustomerEmailDto> saveCustomerEmail({
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
  Future<List<ProductBuyerDto>> getProductBuyers(String productId) async =>
      const [];

  @override
  Future<CustomerCommercialSummaryDto> getCustomerCommercialSummary(
    String customerId,
  ) async => summary ?? CustomerCommercialSummaryDto.empty(customerId);

  @override
  Future<List<CustomerCategoryDto>> getCustomerCategories() async => const [];

  @override
  Future<CustomerCategoryDto> createCustomerCategory({
    required String name,
    String? description,
    String? color,
  }) async => throw UnimplementedError();

  @override
  Future<CustomerCategoryDto> updateCustomerCategory({
    required String id,
    required String name,
    String? description,
    String? color,
    bool isActive = true,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteCustomerCategory(String id) async {}

  final CustomerCommercialSummaryDto? summary;
}
