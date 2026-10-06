import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/documents/documents.dart';

void main() {
  group('A4PdfRenderer', () {
    const renderer = A4PdfRenderer();
    final issueDate = DateTime(2026, 10, 4, 10, 0);

    DocumentModel createDocument({
      int lineCount = 3,
      DocumentStatus status = DocumentStatus.confirmed,
      bool withQr = false,
    }) {
      return DocumentModel(
        metadata: DocumentMetadata(
          documentType: 'FACTURA',
          documentNumber: 'FAC-000100',
          issueDate: issueDate,
          status: status,
          dueDate: issueDate.add(const Duration(days: 30)),
          externalReference: 'OC-9988',
        ),
        issuer: const DocumentParty(
          name: 'Comercializadora SERP S.A.',
          taxId: '3-101-554433',
          address: 'Pavas, San José',
          phone: '2299-8877',
          email: 'facturacion@serp.cr',
        ),
        recipient: const DocumentParty(
          name: 'Supermercado Central',
          legalName: 'Super Central S.A.',
          taxId: '3-102-998877',
          address: 'Heredia Centro',
          phone: '2433-2211',
          email: 'compras@central.cr',
        ),
        responsible: const DocumentParty(name: 'Carlos Agente'),
        lines: List.generate(
          lineCount,
          (i) => DocumentLine(
            itemCode: 'SKU-${i + 1}',
            description: 'Producto de prueba número ${i + 1} con descripción descriptiva',
            quantity: (i + 1) * 2.0,
            unit: 'UND',
            unitPrice: 1500.0,
            discountAmount: i == 0 ? 300.0 : 0.0,
            taxAmount: 390.0,
            taxRate: 0.13,
            total: (i + 1) * 2.0 * 1500.0,
          ),
        ),
        totals: const DocumentTotals(
          subtotal: 18000.0,
          discountTotal: 300.0,
          taxTotal: 2340.0,
          taxBreakdown: [
            DocumentTaxItem(name: 'IVA 13%', rate: 0.13, amount: 2340.0),
          ],
          grandTotal: 20040.0,
          currencyCode: 'CRC',
          currencySymbol: '₡',
        ),
        notes: 'Mercadería entregada a satisfacción.',
        termsAndConditions: 'Términos de pago a 30 días naturales.',
        qrData: withQr ? 'https://serp.cr/verificar/FAC-000100' : null,
      );
    }

    test('renderiza documento A4 básico generando PDF válido', () async {
      final doc = createDocument(lineCount: 2, withQr: true);
      final output = await renderer.render(doc);

      expect(output.bytes, isNotEmpty);
      expect(output.suggestedFileName, 'FACTURA_FAC-000100_2026-10-04_A4.pdf');

      // Un archivo PDF válido inicia con '%PDF-'
      final header = ascii.decode(output.bytes.take(5).toList());
      expect(header, '%PDF-');
    });

    test('renderiza documento sin líneas sin arrojar excepciones', () async {
      final doc = createDocument(lineCount: 0);
      final output = await renderer.render(doc);

      expect(output.bytes, isNotEmpty);
      expect(output.suggestedFileName, contains('_A4.pdf'));
    });

    test('renderiza documento con muchas líneas (multipágina) sin desbordamiento', () async {
      final doc = createDocument(lineCount: 45);
      final output = await renderer.render(doc);

      expect(output.bytes, isNotEmpty);
      expect(output.bytes.length, greaterThan(1000));
    });

    test('renderiza estados especiales con marcas de agua', () async {
      for (final st in [DocumentStatus.draft, DocumentStatus.voided, DocumentStatus.provisional]) {
        final doc = createDocument(status: st);
        final output = await renderer.render(doc);
        expect(output.bytes, isNotEmpty);
      }
    });
  });
}
