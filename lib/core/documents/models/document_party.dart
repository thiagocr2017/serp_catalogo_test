import 'dart:typed_data';

/// Representa una parte interviniente en el documento (emisor, receptor, responsable).
class DocumentParty {
  const DocumentParty({
    required this.name,
    this.legalName,
    this.taxId,
    this.address,
    this.phone,
    this.email,
    this.logoBytes,
  });

  /// Nombre comercial o personal visible.
  final String name;

  /// Razón social fiscal (si difiere del nombre comercial).
  final String? legalName;

  /// Cédula física, jurídica o identificación tributaria.
  final String? taxId;

  /// Dirección física o fiscal.
  final String? address;

  /// Teléfono de contacto.
  final String? phone;

  /// Correo electrónico de contacto o facturación.
  final String? email;

  /// Bytes de imagen con el logotipo (para el emisor).
  final Uint8List? logoBytes;

  /// Devuelve el nombre principal preferido (legalName si existe, sino name).
  String get displayName => (legalName?.trim().isNotEmpty ?? false) ? legalName! : name;
}
