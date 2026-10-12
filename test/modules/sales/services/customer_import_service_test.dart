import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/sales/api/customer_api.dart';
import 'package:serp/modules/sales/services/customer_import_service.dart';

void main() {
  group('CustomerImportService', () {
    late _FakeCustomerApi api;
    late CustomerImportService service;

    setUp(() {
      api = _FakeCustomerApi();
      service = CustomerImportService(api);
    });

    test('template provides canonical headers with semicolon delimiter', () {
      expect(
        service.templateCsv(),
        startsWith('nombre_fiscal;nombre_fantasia;'),
      );
      expect(service.templateCsv(), contains('categorias'));
    });

    test('parses BOM, reordered headers, credit and categories', () {
      final category = CustomerCategoryDto(id: 'category-1', name: 'Mayorista');
      final preview = service.parseCsv(
        '\ufefftelefono;nombre_fantasia;nombre_fiscal;gira;direccion;tipo_cliente;dias_credito;categorias\n'
        '88887777;Comercial Uno;Comercial Uno S.A.;Comercio;San Jose;CREDITO;30;Mayorista',
        existingCustomers: const [],
        categories: [category],
      );

      expect(preview.errors, isEmpty);
      expect(preview.rows, hasLength(1));
      expect(preview.rows.single.customerType, 'CREDIT');
      expect(preview.rows.single.creditDays, 30);
      expect(preview.rows.single.categoryIds, ['category-1']);
    });

    test('rejects missing required data and duplicate rows before persistence', () {
      final preview = service.parseCsv(
        'nombre_fiscal,nombre_fantasia,telefono,gira,direccion,identificacion\n'
        'Empresa,Comercial,88887777,Tienda,San Jose,ABC-1\n'
        'Empresa,Comercial,88887777,Tienda,San Jose,ABC-1\n'
        ',Sin nombre,123,Tienda,San Jose,',
        existingCustomers: const [],
        categories: const [],
      );

      expect(preview.rows, hasLength(1));
      expect(preview.errors, hasLength(2));
      expect(preview.errors.first, contains('Fila 3'));
      expect(preview.errors.first, contains('duplicado'));
      expect(preview.errors.last, contains('nombre fiscal vacío'));
      expect(api.created, isEmpty);
    });

    test('checks existing customer duplicates by tax id', () {
      final preview = service.parseCsv(
        'nombre_fiscal,nombre_fantasia,telefono,gira,direccion,identificacion\n'
        'Otra Empresa,Otra,88887777,Tienda,San Jose,CR-123',
        existingCustomers: const [
          CustomerDto(id: 'existing', name: 'Anterior', taxId: 'CR123'),
        ],
        categories: const [],
      );

      expect(preview.rows, isEmpty);
      expect(preview.errors.single, contains('duplicado'));
    });

    test(
      'creates valid rows with safe defaults and reports row failures',
      () async {
        api.failName = 'Falla';
        final preview = service.parseCsv(
          'nombre_fiscal,nombre_fantasia,telefono,gira,direccion,tipo_cliente,dias_credito\n'
          'Empresa Uno,Uno,88887777,Tienda,San Jose,CONTADO,\n'
          'Empresa Dos,Falla,88886666,Tienda,Heredia,CREDITO,15',
          existingCustomers: const [],
          categories: const [],
        );

        final result = await service.import(preview);

        expect(api.created, hasLength(1));
        expect(api.created.first['documentPreference'], 'TICKET');
        expect(api.created.first['requiresEInvoice'], isFalse);
        expect(api.created.first['customerType'], 'CASH');
        expect(api.created.first['creditDays'], isNull);
        expect(result.created, 1);
        expect(result.errors, hasLength(1));
        expect(result.errors.single, contains('Fila 3'));
      },
    );

    test('rejects credit rows without positive credit days', () {
      final preview = service.parseCsv(
        'nombre_fiscal,nombre_fantasia,telefono,gira,direccion,tipo_cliente\n'
        'Empresa,Comercial,88887777,Tienda,San Jose,CREDITO',
        existingCustomers: const [],
        categories: const [],
      );

      expect(preview.rows, isEmpty);
      expect(preview.errors.single, contains('días positivos'));
    });
  });
}

class _FakeCustomerApi implements CustomerApi {
  final created = <Map<String, Object?>>[];
  String? failName;

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
  }) async {
    if (displayName == failName) throw StateError('fallo simulado');
    created.add({
      'name': name,
      'displayName': displayName,
      'phone': phone,
      'customerType': customerType,
      'creditDays': creditDays,
      'documentPreference': documentPreference,
      'requiresEInvoice': requiresEInvoice,
      'categoryIds': categoryIds,
    });
    return CustomerDto(id: 'new-${created.length}', name: name);
  }

  @override
  Future<List<CustomerDto>> getCustomers() async => const [];

  @override
  Future<CustomerDto?> getCustomerById(String id) async => null;

  @override
  Future<List<CustomerCategoryDto>> getCustomerCategories() async => const [];

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
