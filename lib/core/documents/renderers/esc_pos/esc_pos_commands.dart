import 'dart:convert';

/// Constantes y generador de secuencias de bytes binarias para comandos ESC/POS.
class EscPosCommands {
  static const int esc = 0x1B;
  static const int fs = 0x1C;
  static const int gs = 0x1D;
  static const int lf = 0x0A;

  /// Inicializa la impresora y borra buffers.
  static List<int> init() => [esc, 0x40];

  /// Selecciona página de códigos (ej: 2 para CP850).
  static List<int> selectCodePage(int codePage) => [esc, 0x74, codePage];

  /// Alineación de texto:
  /// 0 = Izquierda, 1 = Centro, 2 = Derecha.
  static List<int> alignLeft() => [esc, 0x61, 0x00];
  static List<int> alignCenter() => [esc, 0x61, 0x01];
  static List<int> alignRight() => [esc, 0x61, 0x02];

  /// Negrita:
  static List<int> boldOn() => [esc, 0x45, 0x01];
  static List<int> boldOff() => [esc, 0x45, 0x00];

  /// Subrayado:
  static List<int> underlineOn() => [esc, 0x2D, 0x01];
  static List<int> underlineOff() => [esc, 0x2D, 0x00];

  /// Tamaño de texto:
  /// [doubleWidth] y [doubleHeight] activan tamaño expandido.
  static List<int> textSize({bool doubleWidth = false, bool doubleHeight = false}) {
    int n = 0;
    if (doubleWidth) n |= 0x20;
    if (doubleHeight) n |= 0x10;
    return [gs, 0x21, n];
  }

  /// Avance de línea.
  static List<int> feedLine([int count = 1]) {
    if (count <= 1) return [lf];
    return [esc, 0x64, count];
  }

  /// Corte parcial de papel.
  static List<int> cutPaper() => [gs, 0x56, 0x01];

  /// Corte con avance previo de [feedLines].
  static List<int> feedAndCut(int feedLines) => [gs, 0x56, 0x42, feedLines];

  /// Genera comandos nativos para imprimir código QR (Modelo 2).
  static List<int> qrCode(String data, {int moduleSize = 5}) {
    final bytes = <int>[];
    final dataBytes = utf8.encode(data);

    // 1. Set model (Model 2)
    bytes.addAll([gs, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);

    // 2. Set module size (1 to 16, default 5)
    bytes.addAll([gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, moduleSize.clamp(1, 16)]);

    // 3. Set error correction level (Level M = 49)
    bytes.addAll([gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);

    // 4. Store data
    final length = dataBytes.length + 3;
    final pL = length & 0xFF;
    final pH = (length >> 8) & 0xFF;
    bytes.addAll([gs, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30, ...dataBytes]);

    // 5. Print QR
    bytes.addAll([gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    return bytes;
  }

  /// Codifica una cadena de texto a bytes compatibles con CP850 (Multilingual).
  static List<int> encodeCp850(String text) {
    final result = <int>[];
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final code = char.codeUnitAt(0);

      // Caracteres ASCII estándar (32 a 126)
      if (code >= 0x20 && code <= 0x7E) {
        result.add(code);
        continue;
      }

      // Mapeo específico para caracteres en español / latinos en CP850
      switch (char) {
        case 'á':
          result.add(0xA0);
          break;
        case 'é':
          result.add(0x82);
          break;
        case 'í':
          result.add(0xA1);
          break;
        case 'ó':
          result.add(0xA2);
          break;
        case 'ú':
          result.add(0xA3);
          break;
        case 'Á':
          result.add(0xB5);
          break;
        case 'É':
          result.add(0x90);
          break;
        case 'Í':
          result.add(0xD6);
          break;
        case 'Ó':
          result.add(0xE0);
          break;
        case 'Ú':
          result.add(0xE9);
          break;
        case 'ñ':
          result.add(0xA4);
          break;
        case 'Ñ':
          result.add(0xA5);
          break;
        case 'ü':
          result.add(0x81);
          break;
        case 'Ü':
          result.add(0x9A);
          break;
        case '¿':
          result.add(0xA8);
          break;
        case '¡':
          result.add(0xAD);
          break;
        case '°':
          result.add(0xF8);
          break;
        case '\n':
          result.add(0x0A);
          break;
        case '\r':
          break;
        case '₡':
          // El símbolo de colón no existe en CP850; degradamos a 'C' legible
          result.add(0x43);
          break;
        default:
          // Fallback a signo de interrogación o representación ascii
          if (code < 128) {
            result.add(code);
          } else {
            result.add(0x3F); // '?'
          }
      }
    }
    return result;
  }
}
