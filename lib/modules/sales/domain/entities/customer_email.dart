/// Proposito de un correo documental del cliente.
enum CustomerEmailPurpose {
  /// Destinatario principal de facturas y documentos.
  primary,

  /// Destinatario en copia.
  copy;

  factory CustomerEmailPurpose.fromJson(String value) => switch (value) {
    'PRIMARY' => CustomerEmailPurpose.primary,
    'COPY' => CustomerEmailPurpose.copy,
    _ => CustomerEmailPurpose.copy,
  };

  String toJson() => switch (this) {
    CustomerEmailPurpose.primary => 'PRIMARY',
    CustomerEmailPurpose.copy => 'COPY',
  };
}

/// Correo documental de un cliente: principal o en copia.
///
/// Ver decisiones 13, 21 y 22 de
/// `.specs/modules/sales/customer-management/0.open-questions.md`.
class CustomerEmail {
  const CustomerEmail({
    required this.id,
    required this.customerId,
    required this.email,
    this.purpose = CustomerEmailPurpose.copy,
    this.label,
    this.isActive = true,
  });

  final String id;
  final String customerId;
  final String email;
  final CustomerEmailPurpose purpose;
  final String? label;
  final bool isActive;
}
