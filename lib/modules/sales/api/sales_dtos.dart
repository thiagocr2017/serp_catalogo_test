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
