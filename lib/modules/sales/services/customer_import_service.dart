import 'package:csv/csv.dart';

import '../../../core/utilities/phone_number.dart';
import '../api/customer_api.dart';

class CustomerImportService {
  const CustomerImportService(this._api);

  final CustomerApi _api;

  static const headers = [
    'nombre_fiscal',
    'nombre_fantasia',
    'telefono',
    'gira',
    'direccion',
    'correo',
    'identificacion',
    'tipo_cliente',
    'dias_credito',
    'limite_credito',
    'codigo_pais',
    'provincia',
    'ciudad',
    'categorias',
  ];

  String templateCsv() => Csv(fieldDelimiter: ';').encode([headers]);

  CustomerImportPreview parseCsv(
    String text, {
    required List<CustomerDto> existingCustomers,
    required List<CustomerCategoryDto> categories,
  }) {
    if (text.trim().isEmpty) {
      return const CustomerImportPreview(
        rows: [],
        errors: ['El archivo está vacío.'],
      );
    }

    final delimiter = _delimiter(text);
    List<List<dynamic>> sourceRows;
    try {
      sourceRows = Csv(
        fieldDelimiter: delimiter,
        autoDetect: false,
      ).decode(text);
    } catch (error) {
      return CustomerImportPreview(
        rows: const [],
        errors: ['No se pudo leer el CSV: $error'],
      );
    }
    if (sourceRows.isEmpty) {
      return const CustomerImportPreview(
        rows: [],
        errors: ['El archivo no contiene encabezados.'],
      );
    }

    final normalizedHeaders = sourceRows.first
        .map((value) => _normalizeHeader(value.toString()))
        .toList();
    final duplicateHeaders =
        normalizedHeaders.toSet().length != normalizedHeaders.length;
    if (duplicateHeaders) {
      return const CustomerImportPreview(
        rows: [],
        errors: ['El archivo contiene encabezados repetidos.'],
      );
    }
    final missingHeaders = const [
      'nombre_fiscal',
      'nombre_fantasia',
      'telefono',
      'gira',
      'direccion',
    ].where((header) => !normalizedHeaders.contains(header)).toList();
    if (missingHeaders.isNotEmpty) {
      return CustomerImportPreview(
        rows: const [],
        errors: ['Faltan columnas obligatorias: ${missingHeaders.join(', ')}.'],
      );
    }
    final indexes = {
      for (var i = 0; i < normalizedHeaders.length; i++)
        normalizedHeaders[i]: i,
    };
    final categoryByName = {
      for (final category in categories.where((item) => item.isActive))
        _normalize(category.name): category,
    };
    final existingKeys = <String>{};
    for (final customer in existingCustomers) {
      existingKeys.addAll(
        _duplicateKeys(
          name: customer.displayName?.trim().isNotEmpty == true
              ? customer.displayName!
              : customer.name,
          phone: customer.phone,
          taxId: customer.taxId,
        ),
      );
    }

    final parsed = <CustomerImportRow>[];
    final errors = <String>[];
    final fileKeys = <String>{};
    for (var i = 1; i < sourceRows.length; i++) {
      final values = sourceRows[i];
      if (values.every((value) => value.toString().trim().isEmpty)) continue;
      final line = i + 1;
      String value(String header) {
        final index = indexes[header];
        return index == null || index >= values.length
            ? ''
            : values[index].toString().trim();
      }

      final name = value('nombre_fiscal');
      final displayName = value('nombre_fantasia');
      final rawPhone = value('telefono');
      final phoneParts = splitPhoneNumber(rawPhone);
      final phone = nullableFormattedPhone(
        countryCode: phoneParts.countryCode,
        localNumber: phoneParts.localNumber,
      );
      final gira = value('gira');
      final address = value('direccion');
      final email = _nullable(value('correo'));
      final taxId = _nullable(value('identificacion'));
      final customerType = _customerType(value('tipo_cliente'));
      final creditDays = _integer(value('dias_credito'));
      final creditLimit = _decimal(value('limite_credito'));
      final countryCode = value('codigo_pais').isEmpty
          ? 'CR'
          : value('codigo_pais').toUpperCase();
      final province = _nullable(value('provincia'));
      final city = _nullable(value('ciudad'));
      final rowErrors = <String>[];

      if (name.isEmpty) rowErrors.add('nombre fiscal vacío');
      if (displayName.isEmpty) rowErrors.add('nombre fantasía vacío');
      if (phone == null || !isValidLocalPhone(phoneParts.localNumber)) {
        rowErrors.add('teléfono inválido (mínimo 8 dígitos locales)');
      }
      if (gira.isEmpty) rowErrors.add('gira vacía');
      if (address.isEmpty) rowErrors.add('dirección vacía');
      if (email != null && !_validEmail(email)) {
        rowErrors.add('correo inválido');
      }
      if (customerType == null) rowErrors.add('tipo de cliente inválido');
      if (customerType == 'CREDIT' && (creditDays == null || creditDays < 1)) {
        rowErrors.add('crédito requiere días positivos');
      }
      if (value('dias_credito').isNotEmpty && creditDays == null) {
        rowErrors.add('días de crédito inválidos');
      }
      if (value('limite_credito').isNotEmpty &&
          (creditLimit == null || creditLimit < 0)) {
        rowErrors.add('límite de crédito inválido');
      }
      if (countryCode.length != 2) {
        rowErrors.add('código de país debe tener 2 letras');
      }

      final categoryNames = value('categorias')
          .split('|')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
      final categoryIds = <String>[];
      for (final categoryName in categoryNames) {
        final category = categoryByName[_normalize(categoryName)];
        if (category == null) {
          rowErrors.add('categoría "$categoryName" inexistente o inactiva');
        } else if (!categoryIds.contains(category.id)) {
          categoryIds.add(category.id);
        }
      }

      final duplicateKeys = _duplicateKeys(
        name: displayName.isEmpty ? name : displayName,
        phone: phone,
        taxId: taxId,
      );
      if (duplicateKeys.any(existingKeys.contains) ||
          duplicateKeys.any(fileKeys.contains)) {
        rowErrors.add(
          'cliente duplicado por identificación o nombre y teléfono',
        );
      }

      if (rowErrors.isNotEmpty) {
        errors.add('Fila $line: ${rowErrors.join('; ')}.');
        continue;
      }
      fileKeys.addAll(duplicateKeys);
      parsed.add(
        CustomerImportRow(
          line: line,
          name: name,
          displayName: displayName,
          phone: phone!,
          email: email,
          address: address,
          taxId: taxId,
          gira: gira,
          customerType: customerType!,
          creditDays: customerType == 'CREDIT' ? creditDays : null,
          creditLimit: creditLimit ?? 0,
          countryCode: countryCode,
          province: province,
          city: city,
          categoryIds: categoryIds,
        ),
      );
    }
    return CustomerImportPreview(rows: parsed, errors: errors);
  }

  Future<CustomerImportResult> import(CustomerImportPreview preview) async {
    var created = 0;
    final errors = <String>[];
    for (final row in preview.rows) {
      try {
        await _api.createCustomer(
          name: row.name,
          displayName: row.displayName,
          phone: row.phone,
          email: row.email,
          address: row.address,
          taxId: row.taxId,
          creditLimit: row.creditLimit,
          countryCode: row.countryCode,
          province: row.province,
          city: row.city,
          gira: row.gira,
          customerType: row.customerType,
          creditDays: row.creditDays,
          documentPreference: 'TICKET',
          requiresEInvoice: false,
          shippingPaymentPolicy: 'INCLUDED',
          categoryIds: row.categoryIds,
        );
        created++;
      } catch (error) {
        errors.add('Fila ${row.line} (${row.displayName}): $error');
      }
    }
    return CustomerImportResult(created: created, errors: errors);
  }

  static String _delimiter(String text) {
    final line = text
        .split(RegExp(r'\r?\n'))
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
    var commas = 0;
    var semicolons = 0;
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && char == ',') {
        commas++;
      } else if (!quoted && char == ';') {
        semicolons++;
      }
    }
    return semicolons > commas ? ';' : ',';
  }

  static String _normalizeHeader(String value) =>
      _normalize(value)
          .replaceFirst('\ufeff', '')
          .replaceAll(RegExp(r'[\s-]+'), '_')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[áàä]'), 'a')
      .replaceAll(RegExp(r'[éèë]'), 'e')
      .replaceAll(RegExp(r'[íìï]'), 'i')
      .replaceAll(RegExp(r'[óòö]'), 'o')
      .replaceAll(RegExp(r'[úùü]'), 'u')
      .replaceAll('ñ', 'n');

  static Set<String> _duplicateKeys({
    required String name,
    required String? phone,
    required String? taxId,
  }) {
    final result = <String>{};
    final normalizedTaxId = taxId
        ?.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    if (normalizedTaxId?.isNotEmpty == true) result.add('tax:$normalizedTaxId');
    final digits = phone == null ? '' : phoneDigitsOnly(phone);
    if (_normalize(name).isNotEmpty && digits.isNotEmpty) {
      result.add('name-phone:${_normalize(name)}:$digits');
    }
    return result;
  }

  static String? _customerType(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty || normalized == 'cash' || normalized == 'contado') {
      return 'CASH';
    }
    if (normalized == 'credit' || normalized == 'credito') return 'CREDIT';
    return null;
  }

  static int? _integer(String value) =>
      value.isEmpty ? null : int.tryParse(value);

  static double? _decimal(String value) {
    if (value.isEmpty) return null;
    return double.tryParse(value.replaceAll(',', '.'));
  }

  static String? _nullable(String value) =>
      value.trim().isEmpty ? null : value.trim();

  static bool _validEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
}

class CustomerImportRow {
  const CustomerImportRow({
    required this.line,
    required this.name,
    required this.displayName,
    required this.phone,
    required this.gira,
    required this.address,
    required this.customerType,
    required this.creditLimit,
    required this.countryCode,
    required this.categoryIds,
    this.email,
    this.taxId,
    this.creditDays,
    this.province,
    this.city,
  });

  final int line;
  final String name;
  final String displayName;
  final String phone;
  final String gira;
  final String address;
  final String customerType;
  final double creditLimit;
  final String countryCode;
  final List<String> categoryIds;
  final String? email;
  final String? taxId;
  final int? creditDays;
  final String? province;
  final String? city;
}

class CustomerImportPreview {
  const CustomerImportPreview({required this.rows, required this.errors});

  final List<CustomerImportRow> rows;
  final List<String> errors;
}

class CustomerImportResult {
  const CustomerImportResult({required this.created, required this.errors});

  final int created;
  final List<String> errors;
}
