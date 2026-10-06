import 'printer_profile.dart';

/// Perfil de capacidades para la impresora térmica portátil Rongta RPP300.
///
/// Especificaciones:
/// - Tecnología: Térmica directa
/// - Papel: 80 mm
/// - Ancho imprimible: 72 mm
/// - Resolución: 203 DPI (8 dots/mm)
/// - Puntos por línea: 576 dots
/// - Caracteres por línea: 48 en Font A (12x24), 64 en Font B (9x17)
/// - Corte automático: No (barra de corte manual)
/// - Código QR: Soportado nativo
/// - Conexión: Bluetooth y USB
class RongtaRpp300Profile extends PrinterProfile {
  const RongtaRpp300Profile();

  @override
  String get name => 'Rongta RPP300';

  @override
  double get paperWidthMm => 80.0;

  @override
  double get printableWidthMm => 72.0;

  @override
  int get dpi => 203;

  @override
  int get dotsPerLine => 576;

  @override
  int get charactersPerLineFontA => 48;

  @override
  int get charactersPerLineFontB => 64;

  @override
  bool get supportsCut => false;

  @override
  bool get supportsQr => true;

  @override
  bool get supportsImages => true;

  @override
  bool get supportsCashDrawer => false;

  @override
  int get defaultFeedLines => 4;

  @override
  int get codePageNumber => 2; // CP850
}
