/// Estados posibles de un documento operativo.
enum DocumentStatus {
  /// Documento no confirmado o en preparación.
  draft,

  /// Documento confirmado y con efectos formales.
  confirmed,

  /// Documento formalmente anulado. Conserva su trazabilidad e historial.
  voided,

  /// Documento emitido localmente fuera de línea aún no sincronizado.
  provisional,
}

/// Metadatos de identificación, fechas y estado de un documento.
class DocumentMetadata {
  const DocumentMetadata({
    required this.documentType,
    required this.documentNumber,
    required this.issueDate,
    this.status = DocumentStatus.confirmed,
    this.externalReference,
    this.dueDate,
  });

  /// Tipo de documento (ej: FACTURA, COTIZACION, PEDIDO, TRASLADO, RECIBO, AJUSTE).
  final String documentType;

  /// Número oficial o correlativo del documento (ej: FAC-000124, TRA-00000152).
  final String documentNumber;

  /// Fecha y hora de emisión del documento.
  final DateTime issueDate;

  /// Estado operativo del documento.
  final DocumentStatus status;

  /// Referencia externa o documento relacionado (ej: OC-4921, COT-00031).
  final String? externalReference;

  /// Fecha de vencimiento o entrega estimada (opcional).
  final DateTime? dueDate;

  /// Texto legible del estado en español.
  String get statusLabel {
    switch (status) {
      case DocumentStatus.draft:
        return 'BORRADOR';
      case DocumentStatus.confirmed:
        return 'CONFIRMADO';
      case DocumentStatus.voided:
        return 'ANULADO';
      case DocumentStatus.provisional:
        return 'PROVISIONAL';
    }
  }

  /// Indica si el documento debe mostrar marca de agua o etiqueta destacada de estado no definitivo.
  bool get hasProminentStatusBanner => status != DocumentStatus.confirmed;
}
