import 'dart:typed_data';

/// Encapsula los bytes de un documento PDF generado y su nombre de archivo sugerido.
class PdfOutput {
  const PdfOutput({
    required this.bytes,
    required this.suggestedFileName,
  });

  /// Bytes binarios del PDF.
  final Uint8List bytes;

  /// Nombre de archivo sugerido según el estándar transversal
  /// (ejemplo: `<TIPO>_<NUMERO>_<FECHA>_A4.pdf`).
  final String suggestedFileName;
}
