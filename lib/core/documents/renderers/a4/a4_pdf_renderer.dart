import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/document_model.dart';
import '../../models/pdf_output.dart';

/// Renderizador de documentos en formato estándar ISO A4.
class A4PdfRenderer {
  const A4PdfRenderer();

  /// Genera los bytes y nombre de archivo para un [DocumentModel] en formato A4.
  Future<PdfOutput> render(DocumentModel document) async {
    final pdf = pw.Document();

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          buildBackground: (context) {
            if (!document.metadata.hasProminentStatusBanner) {
              return pw.SizedBox.shrink();
            }
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Transform.rotateBox(
                  angle: 0.5,
                  child: pw.Text(
                    document.metadata.statusLabel,
                    style: pw.TextStyle(
                      fontSize: 60,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey300,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        header: (context) => _buildHeader(document),
        footer: (context) => _buildFooter(context, document),
        build: (context) => [
          _buildPartiesSection(document),
          pw.SizedBox(height: 16),
          _buildLinesTable(document),
          pw.SizedBox(height: 16),
          _buildTotalsAndNotes(document),
        ],
      ),
    );

    final Uint8List bytes = await pdf.save();
    final fileName = document.generateFileName(suffix: 'A4');

    return PdfOutput(
      bytes: bytes,
      suggestedFileName: fileName,
    );
  }

  pw.Widget _buildHeader(DocumentModel document) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.8),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Logo e información del emisor
          pw.Expanded(
            flex: 3,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (document.issuer.logoBytes != null) ...[
                  pw.Container(
                    width: 60,
                    height: 60,
                    margin: const pw.EdgeInsets.only(right: 12),
                    child: pw.Image(
                      pw.MemoryImage(document.issuer.logoBytes!),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        document.issuer.displayName,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      if (document.issuer.taxId != null &&
                          document.issuer.taxId!.isNotEmpty) ...[
                        pw.Text(
                          'Céd/ID: ${document.issuer.taxId}',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                      if (document.issuer.address != null &&
                          document.issuer.address!.isNotEmpty) ...[
                        pw.Text(
                          document.issuer.address!,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                      if (document.issuer.phone != null &&
                          document.issuer.phone!.isNotEmpty) ...[
                        pw.Text(
                          'Tel: ${document.issuer.phone}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                      if (document.issuer.email != null &&
                          document.issuer.email!.isNotEmpty) ...[
                        pw.Text(
                          'Email: ${document.issuer.email}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          // Cuadro del documento (Número, fecha, tipo)
          pw.Container(
            width: 180,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey200, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              color: PdfColors.grey100,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  document.metadata.documentType.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'No. ${document.metadata.documentNumber}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.Divider(color: PdfColors.grey300, thickness: 0.5),
                _buildMetaRow('Fecha:', _formatDate(document.metadata.issueDate)),
                if (document.metadata.dueDate != null)
                  _buildMetaRow('Vence:', _formatDate(document.metadata.dueDate!)),
                if (document.metadata.externalReference != null &&
                    document.metadata.externalReference!.isNotEmpty)
                  _buildMetaRow('Ref:', document.metadata.externalReference!),
                if (document.metadata.hasProminentStatusBanner)
                  _buildMetaRow('Estado:', document.metadata.statusLabel,
                      isAlert: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetaRow(String label, String value, {bool isAlert = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: isAlert ? PdfColors.red700 : PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPartiesSection(DocumentModel document) {
    final recipient = document.recipient;
    final responsible = document.responsible;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Receptor
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DESTINATARIO / CLIENTE',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 2),
                if (recipient != null) ...[
                  pw.Text(
                    recipient.displayName,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (recipient.taxId != null && recipient.taxId!.isNotEmpty)
                    pw.Text('Céd/ID: ${recipient.taxId}',
                        style: const pw.TextStyle(fontSize: 8)),
                  if (recipient.address != null && recipient.address!.isNotEmpty)
                    pw.Text('Dirección: ${recipient.address}',
                        style: const pw.TextStyle(fontSize: 8)),
                  if (recipient.phone != null && recipient.phone!.isNotEmpty)
                    pw.Text('Teléfono: ${recipient.phone}',
                        style: const pw.TextStyle(fontSize: 8)),
                  if (recipient.email != null && recipient.email!.isNotEmpty)
                    pw.Text('Email: ${recipient.email}',
                        style: const pw.TextStyle(fontSize: 8)),
                ] else ...[
                  pw.Text('Cliente general / Consumidor final',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700)),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          // Responsable y Atributos
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (responsible != null) ...[
                  pw.Text(
                    'RESPONSABLE',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(responsible.name,
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  if (responsible.phone != null && responsible.phone!.isNotEmpty)
                    pw.Text('Tel: ${responsible.phone}',
                        style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 4),
                ],
                if (document.extraAttributes.isNotEmpty) ...[
                  pw.Text(
                    'DETALLES DE LA OPERACIÓN',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                    ),
                  ),
                  ...document.extraAttributes.entries.map(
                    (e) => pw.Text(
                      '${e.key}: ${e.value}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildLinesTable(DocumentModel document) {
    final headers = [
      'Código',
      'Descripción',
      'Cant.',
      'Unidad',
      'Precio',
      'Desc.',
      'Total',
    ];

    final rows = document.lines.map((line) {
      return [
        line.itemCode ?? '',
        line.description,
        line.formattedQuantity,
        line.unit ?? 'UND',
        document.totals.formatAmount(line.unitPrice),
        line.discountAmount > 0
            ? document.totals.formatAmount(line.discountAmount)
            : '-',
        document.totals.formatAmount(line.total),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.blueGrey800,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Código
        1: const pw.FlexColumnWidth(6), // Descripción
        2: const pw.FlexColumnWidth(1.5), // Cantidad
        3: const pw.FlexColumnWidth(1.2), // Unidad
        4: const pw.FlexColumnWidth(2.2), // Precio
        5: const pw.FlexColumnWidth(1.8), // Descuento
        6: const pw.FlexColumnWidth(2.2), // Total
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildTotalsAndNotes(DocumentModel document) {
    final totals = document.totals;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Observaciones y Términos a la izquierda
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (document.notes != null && document.notes!.trim().isNotEmpty) ...[
                pw.Text('NOTAS / OBSERVACIONES:',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(document.notes!,
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey800)),
                pw.SizedBox(height: 8),
              ],
              if (document.termsAndConditions != null &&
                  document.termsAndConditions!.trim().isNotEmpty) ...[
                pw.Text('TÉRMINOS Y CONDICIONES:',
                    style: pw.TextStyle(
                        fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(document.termsAndConditions!,
                    style: const pw.TextStyle(
                        fontSize: 7, color: PdfColors.grey700)),
              ],
              if (document.qrData != null && document.qrData!.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Container(
                  width: 60,
                  height: 60,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: document.qrData!,
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        // Totales a la derecha
        pw.Container(
          width: 200,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            color: PdfColors.grey50,
          ),
          child: pw.Column(
            children: [
              _buildTotalRow('Subtotal:', totals.formatAmount(totals.subtotal)),
              if (totals.discountTotal > 0)
                _buildTotalRow('Descuento total:',
                    '-${totals.formatAmount(totals.discountTotal)}'),
              if (totals.taxTotal > 0) ...[
                _buildTotalRow(
                    'Impuestos:', totals.formatAmount(totals.taxTotal)),
                ...totals.taxBreakdown.map(
                  (t) => _buildTotalRow(
                    '  ${t.name}:',
                    totals.formatAmount(t.amount),
                    isSmall: true,
                  ),
                ),
              ],
              if (totals.rounding != 0)
                _buildTotalRow('Redondeo:', totals.formatAmount(totals.rounding)),
              pw.Divider(color: PdfColors.grey400, thickness: 0.8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL (${totals.currencyCode}):',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  pw.Text(
                    totals.formatAmount(totals.grandTotal),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ],
              ),
              if (totals.exchangeRate != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'T.C. Histórico: ${totals.exchangeRate!.toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTotalRow(String label, String value, {bool isSmall = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isSmall ? 7.5 : 8.5,
              color: isSmall ? PdfColors.grey700 : PdfColors.black,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isSmall ? 7.5 : 8.5,
              fontWeight: isSmall ? pw.FontWeight.normal : pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context, DocumentModel document) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'SERP - ${document.metadata.documentNumber}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }
}
