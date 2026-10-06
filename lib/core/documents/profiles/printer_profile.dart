/// Define las capacidades y especificaciones técnicas de un perfil de impresora térmica.
abstract class PrinterProfile {
  const PrinterProfile();

  /// Nombre comercial y modelo de la impresora.
  String get name;

  /// Ancho físico del papel en milímetros (ej: 80 mm, 58 mm).
  double get paperWidthMm;

  /// Ancho útil de impresión en milímetros (ej: 72 mm para papel de 80 mm).
  double get printableWidthMm;

  /// Resolución en puntos por pulgada (DPI).
  int get dpi;

  /// Cantidad de puntos por línea de impresión horizontal (dots per line).
  int get dotsPerLine;

  /// Cantidad máxima de caracteres por línea utilizando Fuente A (estándar 12x24).
  int get charactersPerLineFontA;

  /// Cantidad máxima de caracteres por línea utilizando Fuente B (compacta 9x17).
  int get charactersPerLineFontB;

  /// Indica si la impresora cuenta con guillotina o autocorte de papel.
  bool get supportsCut;

  /// Indica si la impresora soporta comandos nativos de código QR ESC/POS.
  bool get supportsQr;

  /// Indica si soporta impresión de mapas de bits (imágenes).
  bool get supportsImages;

  /// Indica si soporta comando de apertura de gaveta de dinero.
  bool get supportsCashDrawer;

  /// Cantidad sugerida de líneas de avance en blanco antes de cortar o finalizar.
  int get defaultFeedLines;

  /// Selector de página de códigos ESC/POS (por defecto 2 para CP850 Multilingual).
  int get codePageNumber;
}
