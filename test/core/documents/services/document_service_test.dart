import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/documents/documents.dart';

void main() {
  group('DocumentService y Transición de Transportes', () {
    const service = DocumentService();
    final sampleDate = DateTime(2026, 10, 4, 18, 0);

    final document = DocumentModel(
      metadata: DocumentMetadata(
        documentType: 'AJUSTE',
        documentNumber: 'AJU-000010',
        issueDate: sampleDate,
        status: DocumentStatus.confirmed,
      ),
      issuer: const DocumentParty(
        name: 'Bodega Central SERP',
        phone: '2233-4455',
      ),
      lines: const [
        DocumentLine(
          description: 'Ajuste de inventario por merma',
          quantity: 1,
          unitPrice: 500,
          total: 500,
        ),
      ],
      totals: const DocumentTotals(
        subtotal: 500,
        grandTotal: 500,
      ),
    );

    test('coordina generación de A4 y Ticket 80mm PDF', () async {
      final a4 = await service.renderA4Pdf(document);
      expect(a4.bytes, isNotEmpty);
      expect(a4.suggestedFileName, 'AJUSTE_AJU-000010_2026-10-04_A4.pdf');

      final ticket = await service.renderTicket80mmPdf(document);
      expect(ticket.bytes, isNotEmpty);
      expect(ticket.suggestedFileName, 'AJUSTE_AJU-000010_2026-10-04_TICKET80.pdf');
    });

    test('coordina impresión ESC/POS directa vía MockPrintTransport', () async {
      final transport = MockPrintTransport();
      expect(transport.isConnected, isFalse);

      await service.printEscPosDirect(document, transport: transport);

      expect(transport.isConnected, isTrue);
      expect(transport.sentPayloads.length, 1);
      expect(transport.totalBytesSent, greaterThan(50));
    });

    test('maneja fallos de conexión en el transporte de impresión sin mutar el documento', () async {
      final failingTransport = MockPrintTransport(shouldFailConnection: true);

      expect(
        () => service.printEscPosDirect(document, transport: failingTransport),
        throwsA(isA<StateError>()),
      );

      expect(failingTransport.isConnected, isFalse);
      expect(failingTransport.sentPayloads, isEmpty);
    });

    test('maneja fallos de transmisión durante el envío', () async {
      final failingTransport = MockPrintTransport(shouldFailSend: true);

      expect(
        () => service.printEscPosDirect(document, transport: failingTransport),
        throwsA(isA<StateError>()),
      );
    });
  });
}
