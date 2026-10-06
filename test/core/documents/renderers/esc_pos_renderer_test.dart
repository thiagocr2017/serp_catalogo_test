import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/documents/documents.dart';

void main() {
  group('EscPosRenderer', () {
    const renderer = EscPosRenderer();
    const profile = RongtaRpp300Profile();
    final issueDate = DateTime(2026, 10, 4, 12, 30);

    DocumentModel createDocument({
      String docType = 'FACTURA',
      DocumentStatus status = DocumentStatus.confirmed,
      bool withQr = true,
      String notes = 'Atención rápida en español: camión y piña',
    }) {
      return DocumentModel(
        metadata: DocumentMetadata(
          documentType: docType,
          documentNumber: 'FAC-000555',
          issueDate: issueDate,
          status: status,
        ),
        issuer: const DocumentParty(
          name: 'Comercializadora SERP',
          taxId: '3-101-112233',
          phone: '2233-4455',
          address: 'Alajuela, Costa Rica',
        ),
        recipient: const DocumentParty(
          name: 'Juan Pérez',
          taxId: '1-0987-0654',
          phone: '8765-4321',
        ),
        responsible: const DocumentParty(name: 'Pedro Despachador'),
        lines: const [
          DocumentLine(
            description: 'Café Grano Especial 500g',
            quantity: 2,
            unit: 'PAQ',
            unitPrice: 3500.0,
            discountAmount: 500.0,
            total: 6500.0,
          ),
        ],
        totals: const DocumentTotals(
          subtotal: 7000.0,
          discountTotal: 500.0,
          grandTotal: 6500.0,
          currencyCode: 'CRC',
          currencySymbol: '₡',
        ),
        notes: notes,
        qrData: withQr ? 'https://serp.cr/f/FAC-000555' : null,
      );
    }

    test('genera encabezados iniciales y selección de página de código CP850', () {
      final doc = createDocument();
      final Uint8List bytes = renderer.render(doc, profile: profile);

      expect(bytes, isNotEmpty);

      // Comienza con ESC @ (0x1B, 0x40)
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);

      // Selecciona página de código ESC t 2 (0x1B, 0x74, 0x02)
      expect(bytes[2], 0x1B);
      expect(bytes[3], 0x74);
      expect(bytes[4], 0x02);
    });

    test('codifica correctamente caracteres en español para CP850', () {
      final encoded = EscPosCommands.encodeCp850('áéíóúñÑ');
      // Mapeo CP850:
      // á = 0xA0, é = 0x82, í = 0xA1, ó = 0xA2, ú = 0xA3, ñ = 0xA4, Ñ = 0xA5
      expect(encoded, [0xA0, 0x82, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5]);
    });

    test('incluye comandos nativos de código QR cuando qrData está presente', () {
      final doc = createDocument(withQr: true);
      final bytes = renderer.render(doc, profile: profile);

      // Comando QR en ESC/POS contiene GS ( k [0x1D, 0x28, 0x6B]
      bool foundQrCommand = false;
      for (int i = 0; i < bytes.length - 2; i++) {
        if (bytes[i] == 0x1D && bytes[i + 1] == 0x28 && bytes[i + 2] == 0x6B) {
          foundQrCommand = true;
          break;
        }
      }

      expect(foundQrCommand, isTrue);
    });

    test('muestra banner de estado en documentos borradores o anulados', () {
      final docDraft = createDocument(status: DocumentStatus.draft);
      final bytesDraft = renderer.render(docDraft, profile: profile);

      // Debe contener la palabra BORRADOR en bytes ascii
      final asString = String.fromCharCodes(bytesDraft);
      expect(asString, contains('*** BORRADOR ***'));

      final docVoid = createDocument(status: DocumentStatus.voided);
      final bytesVoid = renderer.render(docVoid, profile: profile);
      final asStringVoid = String.fromCharCodes(bytesVoid);
      expect(asStringVoid, contains('*** ANULADO ***'));
    });

    test('aplica corte de papel cuando el perfil lo soporta', () {
      final doc = createDocument();
      final bytes = renderer.render(doc, profile: const _CuttableProfile());

      // El corte termina con GS V 1 [0x1D, 0x56, 0x01]
      expect(bytes.sublist(bytes.length - 3), [0x1D, 0x56, 0x01]);
    });
  });
}

class _CuttableProfile extends RongtaRpp300Profile {
  const _CuttableProfile();

  @override
  bool get supportsCut => true;
}
