import 'dart:typed_data';

import '../../models/document_line.dart';
import '../../models/document_model.dart';
import '../../profiles/printer_profile.dart';
import '../../profiles/rongta_rpp300_profile.dart';
import 'esc_pos_commands.dart';

/// Motor de renderizado directo a comandos binarios ESC/POS para impresoras térmicas.
class EscPosRenderer {
  const EscPosRenderer({
    this.defaultProfile = const RongtaRpp300Profile(),
  });

  /// Perfil de capacidades por defecto (Rongta RPP300).
  final PrinterProfile defaultProfile;

  /// Renderiza un [DocumentModel] en una secuencia de bytes binarios ESC/POS.
  Uint8List render(
    DocumentModel document, {
    PrinterProfile? profile,
  }) {
    final activeProfile = profile ?? defaultProfile;
    final bytes = <int>[];
    final cpl = activeProfile.charactersPerLineFontA;

    void add(List<int> cmd) => bytes.addAll(cmd);
    void textLine(String text) {
      add(EscPosCommands.encodeCp850(text));
      add(EscPosCommands.feedLine());
    }

    void divider([String char = '-']) {
      textLine(char * cpl);
    }

    // 1. Inicialización y página de códigos
    add(EscPosCommands.init());
    add(EscPosCommands.selectCodePage(activeProfile.codePageNumber));

    // 2. Encabezado de la empresa (Emisor)
    add(EscPosCommands.alignCenter());
    add(EscPosCommands.boldOn());
    add(EscPosCommands.textSize(doubleWidth: true, doubleHeight: true));
    textLine(document.issuer.displayName.toUpperCase());
    add(EscPosCommands.textSize()); // normal
    add(EscPosCommands.boldOff());

    if (document.issuer.taxId != null && document.issuer.taxId!.isNotEmpty) {
      textLine('Céd/ID: ${document.issuer.taxId}');
    }
    if (document.issuer.address != null && document.issuer.address!.isNotEmpty) {
      textLine(document.issuer.address!);
    }
    if (document.issuer.phone != null && document.issuer.phone!.isNotEmpty) {
      textLine('Tel: ${document.issuer.phone}');
    }

    divider();

    // 3. Metadatos del documento
    add(EscPosCommands.alignLeft());
    add(EscPosCommands.boldOn());
    textLine('${document.metadata.documentType.toUpperCase()} No. ${document.metadata.documentNumber}');
    add(EscPosCommands.boldOff());

    textLine('Fecha: ${_formatDateTime(document.metadata.issueDate)}');
    if (document.metadata.dueDate != null) {
      textLine('Vence: ${_formatDateTime(document.metadata.dueDate!)}');
    }
    if (document.metadata.externalReference != null &&
        document.metadata.externalReference!.isNotEmpty) {
      textLine('Ref: ${document.metadata.externalReference}');
    }

    if (document.metadata.hasProminentStatusBanner) {
      add(EscPosCommands.alignCenter());
      add(EscPosCommands.boldOn());
      textLine('*** ${document.metadata.statusLabel} ***');
      add(EscPosCommands.boldOff());
      add(EscPosCommands.alignLeft());
    }

    // 4. Receptor (si existe)
    if (document.recipient != null) {
      divider();
      final r = document.recipient!;
      add(EscPosCommands.boldOn());
      textLine('CLIENTE: ${r.displayName}');
      add(EscPosCommands.boldOff());
      if (r.taxId != null && r.taxId!.isNotEmpty) {
        textLine('ID/Céd: ${r.taxId}');
      }
      if (r.address != null && r.address!.isNotEmpty) {
        textLine('Dir: ${r.address}');
      }
      if (r.phone != null && r.phone!.isNotEmpty) {
        textLine('Tel: ${r.phone}');
      }
    }

    // 5. Líneas del documento
    divider();
    textLine(_formatTwoColumns('DESCRIPCIÓN', 'TOTAL', cpl));
    divider('-');

    for (final line in document.lines) {
      _renderLineItem(line, document, cpl, textLine);
    }

    // 6. Totales
    divider('=');
    final totals = document.totals;
    textLine(_formatTwoColumns('Subtotal:', totals.formatAmount(totals.subtotal), cpl));

    if (totals.discountTotal > 0) {
      textLine(_formatTwoColumns(
        'Descuento:',
        '-${totals.formatAmount(totals.discountTotal)}',
        cpl,
      ));
    }

    if (totals.taxTotal > 0) {
      textLine(_formatTwoColumns(
        'Impuestos:',
        totals.formatAmount(totals.taxTotal),
        cpl,
      ));
    }

    if (totals.rounding != 0) {
      textLine(_formatTwoColumns(
        'Redondeo:',
        totals.formatAmount(totals.rounding),
        cpl,
      ));
    }

    add(EscPosCommands.boldOn());
    textLine(_formatTwoColumns(
      'TOTAL (${totals.currencyCode}):',
      totals.formatAmount(totals.grandTotal),
      cpl,
    ));
    add(EscPosCommands.boldOff());

    // 7. Notas u observaciones
    if (document.notes != null && document.notes!.trim().isNotEmpty) {
      divider();
      add(EscPosCommands.boldOn());
      textLine('NOTAS:');
      add(EscPosCommands.boldOff());
      textLine(document.notes!.trim());
    }

    // 8. Términos y condiciones
    if (document.termsAndConditions != null &&
        document.termsAndConditions!.trim().isNotEmpty) {
      divider();
      textLine(document.termsAndConditions!.trim());
    }

    // 9. Código QR (si el perfil lo soporta)
    if (document.qrData != null && document.qrData!.trim().isNotEmpty) {
      if (activeProfile.supportsQr) {
        add(EscPosCommands.feedLine());
        add(EscPosCommands.alignCenter());
        add(EscPosCommands.qrCode(document.qrData!.trim()));
        add(EscPosCommands.feedLine());
        add(EscPosCommands.alignLeft());
      } else {
        // Fallback textual si no soporta QR
        add(EscPosCommands.alignCenter());
        textLine('[QR: ${document.qrData!.trim()}]');
        add(EscPosCommands.alignLeft());
      }
    }

    // 10. Pie de página
    add(EscPosCommands.alignCenter());
    add(EscPosCommands.feedLine());
    textLine('¡Gracias por su preferencia!');
    if (document.responsible != null) {
      textLine('Atendido por: ${document.responsible!.name}');
    }

    // 11. Avance final y corte
    add(EscPosCommands.feedLine(activeProfile.defaultFeedLines));
    if (activeProfile.supportsCut) {
      add(EscPosCommands.cutPaper());
    }

    return Uint8List.fromList(bytes);
  }

  void _renderLineItem(
    DocumentLine line,
    DocumentModel document,
    int cpl,
    void Function(String) textLine,
  ) {
    // 1ra línea: Descripción (ajustada si es más ancha que cpl)
    final desc = line.description;
    textLine(desc);

    // 2da línea: Desglose Cant x Precio a la izquierda, Total a la derecha
    final leftPart = '  ${line.formattedQuantity} ${line.unit ?? "UND"} x ${document.totals.formatAmount(line.unitPrice)}'
        '${line.discountAmount > 0 ? " (-${document.totals.formatAmount(line.discountAmount)})" : ""}';
    final rightPart = document.totals.formatAmount(line.total);

    textLine(_formatTwoColumns(leftPart, rightPart, cpl));
  }

  String _formatTwoColumns(String left, String right, int width) {
    if (left.length + right.length >= width) {
      final availableLeft = width - right.length - 1;
      if (availableLeft > 0) {
        left = left.substring(0, availableLeft);
      }
    }
    final spaces = width - (left.length + right.length);
    final padding = ' ' * (spaces > 0 ? spaces : 1);
    return '$left$padding$right';
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }
}
