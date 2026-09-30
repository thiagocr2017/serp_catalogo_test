/// Trazabilidad neutral para comandos de negocio.
///
/// Durante el desarrollo local sus valores proceden del equipo. No representa
/// autenticación ni autorización; el futuro módulo de Auth lo suplirá sin que
/// los módulos funcionales dependan de Supabase Auth.
class IdentityContext {
  const IdentityContext({
    required this.actorName,
    required this.deviceName,
    required this.deviceIdentifier,
  });

  final String actorName;
  final String deviceName;
  final String deviceIdentifier;
}
