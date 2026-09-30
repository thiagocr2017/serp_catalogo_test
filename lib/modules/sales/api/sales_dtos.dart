/// Contrato de lectura público para agentes de Ventas.
class SalesAgentDto {
  const SalesAgentDto({
    required this.id,
    required this.name,
    required this.phone,
    required this.isActive,
    required this.version,
  });

  final String id;
  final String name;
  final String phone;
  final bool isActive;
  final int version;
}

/// Define si una consulta incluye agentes desactivados.
class SalesAgentQuery {
  const SalesAgentQuery({this.activeOnly = false});

  final bool activeOnly;
}
