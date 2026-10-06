import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/document_line.dart';
import '../../models/document_model.dart';
import '../../models/pdf_output.dart';

/// Renderizador de documentos en formato Ticket térmico de 80 mm.
///
/// Optimizado para impresoras térmicas de 80 mm (72 mm de ancho útil) a 203 DPI:
/// - Diseño monocromático sin fondos negros sólidos.
/// - Separadores legibles de bajo consumo térmico.
/// - Tipografía proporcional de alta legibilidad.
/// - Altura continua adaptada al contenido para evitar páginas vacías.
class Ticket80mmPdfRenderer {
  const Ticket80mmPdfRenderer();

  /// Genera los bytes y nombre de archivo para un [DocumentModel] en formato Ticket 80mm.
  Future<PdfOutput> render(DocumentModel document) async {
    final pdf = pw.Document();

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    final pageHeight = _calculatePageHeight(document);
    final pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      pageHeight,
      marginLeft: 4 * PdfPageFormat.mm,
      marginRight: 4 * PdfPageFormat.mm,
      marginTop: 4 * PdfPageFormat.mm,
      marginBottom: 6 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildIssuerHeader(document),
              _buildDivider(),
              _buildDocumentMeta(document),
              if (document.recipient != null) ...[
                _buildDivider(),
                _buildRecipient(document),
              ],
              _buildDivider(),
              _buildItemsSection(document),
              _buildDivider(),
              _buildTotals(document),
              if (document.notes != null && document.notes!.trim().isNotEmpty) ...[
                _buildDivider(),
                _buildNotes(document),
              ],
              if (document.qrData != null && document.qrData!.trim().isNotEmpty) ...[
                _buildDivider(),
                _buildQrCode(document),
              ],
              _buildFooter(document),
            ],
          );
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    final fileName = document.generateFileName(suffix: 'TICKET80');

    return PdfOutput(
      bytes: bytes,
      suggestedFileName: fileName,
    );
  }

  double _calculatePageHeight(DocumentModel document) {
    // Estimación dinámica de altura en milímetros para formato continuo
    double mm = 35.0; // Emisor y márgenes
    mm += 25.0; // Metadatos del documento
    if (document.recipient != null) mm += 22.0;
    if (document.responsible != null) mm += 12.0;

    // Líneas: cada línea ocupa en promedio 12-16mm con descripción y desglose
    mm += document.lines.length * 15.0;

    // Totales
    mm += 35.0;
    if (document.totals.discountTotal > 0) mm += 6.0;
    if (document.totals.taxTotal > 0) mm += 6.0;

    // Notas y términos
    if (document.notes != null && document.notes!.trim().isNotEmpty) {
      mm += 18.0;
    }
    if (document.termsAndConditions != null &&
        document.termsAndConditions!.trim().isNotEmpty) {
      mm += 16.0;
    }

    // QR
    if (document.qrData != null && document.qrData!.trim().isNotEmpty) {
      mm += 35.0;
    }

    // Pie de página y espacio final
    mm += 20.0;

    return (mm * PdfPageFormat.mm).clamp(
      120 * PdfPageFormat.mm,
      3000 * PdfPageFormat.mm,
    );
  }

  pw.Widget _buildIssuerHeader(DocumentModel document) {
    final issuer = document.issuer;
    return pw.Column(
      children: [
        if (issuer.logoBytes != null) ...[
          pw.Container(
            height: 36,
            child: pw.Image(
              pw.MemoryImage(issuer.logoBytes!),
              fit: pw.BoxFit.contain,
            ),
          ),
          pw.SizedBox(height: 3),
        ],
        pw.Text(
          issuer.displayName.toUpperCase(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (issuer.taxId != null && issuer.taxId!.isNotEmpty) ...[
          pw.Text(
            'Céd/ID: ${issuer.taxId}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7.5),
          ),
        ],
        if (issuer.address != null && issuer.address!.isNotEmpty) ...[
          pw.Text(
            issuer.address!,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7),
          ),
        ],
        if (issuer.phone != null && issuer.phone!.isNotEmpty) ...[
          pw.Text(
            'Tel: ${issuer.phone}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildDocumentMeta(DocumentModel document) {
    final meta = document.metadata;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              meta.documentType.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              meta.documentNumber,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 1),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Fecha:', style: const pw.TextStyle(fontSize: 7.5)),
            pw.Text(_formatDate(meta.issueDate),
                style: const pw.TextStyle(fontSize: 7.5)),
          ],
        ),
        if (meta.dueDate != null) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Vence:', style: const pw.TextStyle(fontSize: 7.5)),
              pw.Text(_formatDate(meta.dueDate!),
                  style: const pw.TextStyle(fontSize: 7.5)),
            ],
          ),
        ],
        if (meta.externalReference != null &&
            meta.externalReference!.isNotEmpty) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Ref:', style: const pw.TextStyle(fontSize: 7.5)),
              pw.Text(meta.externalReference!,
                  style: const pw.TextStyle(fontSize: 7.5)),
            ],
          ),
        ],
        if (meta.hasProminentStatusBanner) ...[
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              '*** ${meta.statusLabel} ***',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildRecipient(DocumentModel document) {
    final r = document.recipient!;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CLIENTE: ${r.displayName}',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
        if (r.taxId != null && r.taxId!.isNotEmpty)
          pw.Text('ID/Céd: ${r.taxId}', style: const pw.TextStyle(fontSize: 7)),
        if (r.address != null && r.address!.isNotEmpty)
          pw.Text('Dir: ${r.address}', style: const pw.TextStyle(fontSize: 7)),
        if (r.phone != null && r.phone!.isNotEmpty)
          pw.Text('Tel: ${r.phone}', style: const pw.TextStyle(fontSize: 7)),
      ],
    );
  }

  pw.Widget _buildItemsSection(DocumentModel document) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                'DESCRIPCIÓN',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text(
              'TOTAL',
              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        ...document.lines.map((line) => _buildItemLine(line, document)),
      ],
    );
  }

  pw.Widget _buildItemLine(DocumentLine line, DocumentModel document) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            line.description,
            style: const pw.TextStyle(fontSize: 7.5),
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '  ${line.formattedQuantity} ${line.unit ?? "UND"} x ${document.totals.formatAmount(line.unitPrice)}'
                '${line.discountAmount > 0 ? " (Desc. -${document.totals.formatAmount(line.discountAmount)})" : ""}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
              ),
              pw.Text(
                document.totals.formatAmount(line.total),
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotals(DocumentModel document) {
    final totals = document.totals;
    return pw.Column(
      children: [
        _buildTotalLine('Subtotal:', totals.formatAmount(totals.subtotal)),
        if (totals.discountTotal > 0)
          _buildTotalLine('Descuento:',
              '-${totals.formatAmount(totals.discountTotal)}'),
        if (totals.taxTotal > 0)
          _buildTotalLine('Impuestos:', totals.formatAmount(totals.taxTotal)),
        if (totals.rounding != 0)
          _buildTotalLine('Redondeo:', totals.formatAmount(totals.rounding)),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'TOTAL (${totals.currencyCode}):',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              totals.formatAmount(totals.grandTotal),
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTotalLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.5)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 7.5)),
        ],
      ),
    );
  }

  pw.Widget _buildNotes(DocumentModel document) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('NOTAS:',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        pw.Text(document.notes!, style: const pw.TextStyle(fontSize: 6.5)),
      ],
    );
  }

  pw.Widget _buildQrCode(DocumentModel document) {
    return pw.Center(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 4),
        width: 55,
        height: 55,
        child: pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: document.qrData!,
        ),
      ),
    );
  }

  pw.Widget _buildFooter(DocumentModel document) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 6),
        pw.Text(
          '¡Gracias por su preferencia!',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 7.5),
        ),
        if (document.responsible != null) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            'Atendido por: ${document.responsible!.name}',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700),
          ),
        ],
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildDivider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Divider(color: PdfColors.grey500, thickness: 0.5),
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }
}
