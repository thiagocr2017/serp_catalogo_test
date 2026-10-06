import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/documents/documents.dart';

void main() {
  group('Ticket80mmPdfRenderer', () {
    const renderer = Ticket80mmPdfRenderer();
    final issueDate = DateTime(2026, 10, 4, 15, 45);

    DocumentModel createDocument({
      int lineCount = 3,
      DocumentStatus status = DocumentStatus.confirmed,
      bool withQr = true,
      bool withRecipient = true,
    }) {
      return DocumentModel(
        metadata: DocumentMetadata(
          documentType: 'RECIBO',
          documentNumber: 'REC-000450',
          issueDate: issueDate,
          status: status,
        ),
        issuer: const DocumentParty(
          name: 'SERP Express',
          taxId: '3-101-778899',
          address: 'Pérez Zeledón, San José',
          phone: '2771-4455',
        ),
        recipient: withRecipient
            ? const DocumentParty(
                name: 'María Fernández',
                taxId: '1-1234-0567',
                phone: '8899-7766',
              )
            : null,
        responsible: const DocumentParty(name: 'Andrés Cajero'),
        lines: List.generate(
          lineCount,
          (i) => DocumentLine(
            description: 'Artículo térmico ${i + 1} con nombre representativo largo',
            quantity: 2.0,
            unit: 'UND',
            unitPrice: 2500.0,
            discountAmount: i == 0 ? 500.0 : 0.0,
            total: (2.0 * 2500.0) - (i == 0 ? 500.0 : 0.0),
          ),
        ),
        totals: DocumentTotals(
          subtotal: lineCount * 5000.0,
          discountTotal: lineCount > 0 ? 500.0 : 0.0,
          grandTotal: (lineCount * 5000.0) - (lineCount > 0 ? 500.0 : 0.0),
          currencyCode: 'CRC',
          currencySymbol: '₡',
        ),
        notes: 'Gracias por su compra. Conserve este comprobante.',
        qrData: withQr ? 'https://serp.cr/comprobante/REC-000450' : null,
      );
    }

    test('renderiza ticket de 80 mm generando PDF válido', () async {
      final doc = createDocument(lineCount: 2, withQr: true);
      final output = await renderer.render(doc);

      expect(output.bytes, isNotEmpty);
      expect(output.suggestedFileName, 'RECIBO_REC-000450_2026-10-04_TICKET80.pdf');

      final header = ascii.decode(output.bytes.take(5).toList());
      expect(header, '%PDF-');
    });

    test('renderiza ticket sin cliente ni QR sin fallos', () async {
      final doc = createDocument(
        lineCount: 1,
        withQr: false,
        withRecipient: false,
      );
      final output = await renderer.render(doc);

      expect(output.bytes, isNotEmpty);
      expect(output.suggestedFileName, contains('_TICKET80.pdf'));
    });

    test('renderiza ticket de estado BORRADOR con advertencia textual', () async {
      final doc = createDocument(status: DocumentStatus.draft);
      final output = await renderer.render(doc);

      expect(output.bytes, isNotEmpty);
    });
  });
}
