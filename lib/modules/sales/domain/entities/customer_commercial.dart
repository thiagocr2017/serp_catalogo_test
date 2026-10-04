/// Persona de contacto dentro de una empresa cliente.
class CustomerContact {
  const CustomerContact({
    required this.id,
    required this.customerId,
    required this.name,
    this.phone,
    this.role,
    this.birthday,
  });

  final String id;
  final String customerId;
  final String name;
  final String? phone;
  final DateTime? birthday;

  /// Rol en la empresa (p. ej. Compras, Gerencia).
  final String? role;
}

/// Cliente que compra un producto, con resumen de compras y contactos
/// embebidos para la búsqueda del display de producto.
class ProductBuyer {
  const ProductBuyer({
    required this.customerId,
    required this.name,
    this.phone,
    this.email,
    this.province,
    this.gira,
    this.isActive = true,
    this.lastPurchaseAt,
    this.totalQuantity = 0,
    this.documentsCount = 0,
    this.contacts = const [],
  });

  final String? customerId;

  /// Nombre del cliente o del comprador sin ficha (venta de mostrador).
  final String name;
  final String? phone;
  final String? email;
  final String? province;

  /// Agrupación comercial libre (p. ej. la ruta o gira de visita).
  final String? gira;
  final bool isActive;
  final DateTime? lastPurchaseAt;
  final int totalQuantity;
  final int documentsCount;
  final List<CustomerContact> contacts;

  /// verdadero si todos los términos aparecen en nombre, teléfono, email,
  /// provincia, gira o alguno de los contactos.
  bool matchesQuery(String query) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    if (terms.isEmpty) return true;
    final haystack = [
      name,
      phone,
      email,
      province,
      gira,
      for (final contact in contacts) ...[
        contact.name,
        contact.phone,
        contact.role,
      ],
    ].whereType<String>().join(' ').toLowerCase();
    return terms.every(haystack.contains);
  }
}

/// Filtra compradores por texto libre (nombre, contactos, provincia, gira).
List<ProductBuyer> filterProductBuyers(
  List<ProductBuyer> buyers,
  String query,
) => buyers.where((buyer) => buyer.matchesQuery(query)).toList();
