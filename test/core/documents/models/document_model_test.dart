import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/documents/documents.dart';

void main() {
  group('DocumentModel y Nomenclatura', () {
    final sampleDate = DateTime(2026, 9, 29, 14, 30);

    final sampleDoc = DocumentModel(
      metadata: DocumentMetadata(
        documentType: 'TRASLADO',
        documentNumber: 'TRA-00000152',
        issueDate: sampleDate,
        status: DocumentStatus.confirmed,
      ),
      issuer: const DocumentParty(
        name: 'Distribuidora SERP',
        legalName: 'SERP Soluciones Comerciales S.A.',
        taxId: '3-101-987654',
        address: 'San José, Costa Rica',
        phone: '2222-3333',
        email: 'info@serp.cr',
      ),
      recipient: const DocumentParty(
        name: 'Supermercado El Sol',
        taxId: '3-102-112233',
        address: 'Alajuela, Costa Rica',
      ),
      lines: const [
        DocumentLine(
          itemCode: 'PRD-01',
          description: 'Arroz Grano Entero 1kg',
          quantity: 10,
          unit: 'KG',
          unitPrice: 1200.0,
          total: 12000.0,
        ),
      ],
      totals: const DocumentTotals(
        subtotal: 12000.0,
        grandTotal: 12000.0,
        currencyCode: 'CRC',
        currencySymbol: '₡',
      ),
    );

    test('genera nombre de archivo estandarizado A4', () {
      final fileName = sampleDoc.generateFileName(suffix: 'A4');
      expect(fileName, 'TRASLADO_TRA-00000152_2026-09-29_A4.pdf');
    });

    test('genera nombre de archivo estandarizado Ticket 80mm', () {
      final fileName = sampleDoc.generateFileName(suffix: 'TICKET80');
      expect(fileName, 'TRASLADO_TRA-00000152_2026-09-29_TICKET80.pdf');
    });

    test('sanitiza tipos y números con caracteres especiales o espacios', () {
      final customDoc = DocumentModel(
        metadata: DocumentMetadata(
          documentType: 'RECIBO DE CAJA',
          documentNumber: 'TL/RC/000125',
          issueDate: sampleDate,
          status: DocumentStatus.draft,
        ),
        issuer: const DocumentParty(name: 'SERP'),
        lines: const [],
        totals: const DocumentTotals(subtotal: 0, grandTotal: 0),
      );

      final fileName = customDoc.generateFileName(suffix: 'TICKET80');
      expect(fileName, 'RECIBO_DE_CAJA_TL-RC-000125_2026-09-29_TICKET80.pdf');
    });

    test('verifica etiquetas de estado y banner prominente', () {
      expect(sampleDoc.metadata.statusLabel, 'CONFIRMADO');
      expect(sampleDoc.metadata.hasProminentStatusBanner, isFalse);

      final draftMeta = DocumentMetadata(
        documentType: 'PEDIDO',
        documentNumber: 'PED-1',
        issueDate: sampleDate,
        status: DocumentStatus.draft,
      );
      expect(draftMeta.statusLabel, 'BORRADOR');
      expect(draftMeta.hasProminentStatusBanner, isTrue);

      final voidedMeta = DocumentMetadata(
        documentType: 'FACTURA',
        documentNumber: 'FAC-1',
        issueDate: sampleDate,
        status: DocumentStatus.voided,
      );
      expect(voidedMeta.statusLabel, 'ANULADO');
      expect(voidedMeta.hasProminentStatusBanner, isTrue);

      final provMeta = DocumentMetadata(
        documentType: 'RECIBO',
        documentNumber: 'REC-1',
        issueDate: sampleDate,
        status: DocumentStatus.provisional,
      );
      expect(provMeta.statusLabel, 'PROVISIONAL');
      expect(provMeta.hasProminentStatusBanner, isTrue);
    });

    test('formatea cantidades y montos monetarios correctamente', () {
      const lineInt = DocumentLine(
        description: 'Item 1',
        quantity: 5.0,
        unitPrice: 100,
        total: 500,
      );
      expect(lineInt.formattedQuantity, '5');

      const lineDec = DocumentLine(
        description: 'Item 2',
        quantity: 3.75,
        unitPrice: 100,
        total: 375,
      );
      expect(lineDec.formattedQuantity, '3.75');

      const totals = DocumentTotals(
        subtotal: 1500000.50,
        grandTotal: 1500000.50,
        currencySymbol: '₡',
      );
      expect(totals.formatAmount(1500000.50), '₡1,500,000.50');
    });
  });
}
