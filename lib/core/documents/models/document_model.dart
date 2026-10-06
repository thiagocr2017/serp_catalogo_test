import 'document_line.dart';
import 'document_metadata.dart';
import 'document_party.dart';
import 'document_totals.dart';

/// Modelo de documento agnóstico del módulo propietario.
///
/// Encapsula de forma inmutable la representación histórica de cualquier
/// documento operativo confirmado o provisional en el sistema (ventas, inventario,
/// recibos, ajustes, etc.).
class DocumentModel {
  const DocumentModel({
    required this.metadata,
    required this.issuer,
    required this.lines,
    required this.totals,
    this.recipient,
    this.responsible,
    this.notes,
    this.termsAndConditions,
    this.qrData,
    this.extraAttributes = const {},
  });

  /// Metadatos de identificación, tipo, fecha y estado.
  final DocumentMetadata metadata;

  /// Emisor del documento (empresa o sucursal).
  final DocumentParty issuer;

  /// Receptor del documento (cliente, proveedor o contraparte).
  final DocumentParty? recipient;

  /// Agente, usuario, despachador o responsable de la operación.
  final DocumentParty? responsible;

  /// Líneas o renglones del documento en orden estricto.
  final List<DocumentLine> lines;

  /// Totales, moneda e impuestos calculados.
  final DocumentTotals totals;

  /// Observaciones generales o notas para el cliente.
  final String? notes;

  /// Términos, condiciones comerciales o cláusulas legales al pie.
  final String? termsAndConditions;

  /// Contenido de texto o URL a codificar en código QR.
  final String? qrData;

  /// Atributos adicionales clave-valor (ej: bodega, transporte, plazo).
  final Map<String, String> extraAttributes;

  /// Genera el nombre de archivo estandarizado según la norma transversal:
  /// `<TIPO>_<NUMERO>_<FECHA>_<SUFFIX>.<EXT>`
  ///
  /// Ejemplos:
  /// `TRASLADO_TRA-00000152_2026-09-29_A4.pdf`
  /// `RECIBO_TL-RC-000125_2026-09-29_TICKET80.pdf`
  String generateFileName({
    required String suffix,
    String extension = 'pdf',
  }) {
    final sanitizedType = metadata.documentType
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
    final sanitizedNumber = metadata.documentNumber
        .trim()
        .replaceAll(RegExp(r'[\s/\\:]+'), '-');

    final year = metadata.issueDate.year.toString().padLeft(4, '0');
    final month = metadata.issueDate.month.toString().padLeft(2, '0');
    final day = metadata.issueDate.day.toString().padLeft(2, '0');
    final dateStr = '$year-$month-$day';

    final cleanSuffix = suffix.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final cleanExt = extension.replaceAll('.', '').trim();

    return '${sanitizedType}_${sanitizedNumber}_${dateStr}_$cleanSuffix.$cleanExt';
  }
}
