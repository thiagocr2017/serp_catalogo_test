import 'dart:typed_data';

import '../models/document_model.dart';
import '../models/pdf_output.dart';
import '../profiles/printer_profile.dart';
import '../profiles/rongta_rpp300_profile.dart';
import '../renderers/a4/a4_pdf_renderer.dart';
import '../renderers/esc_pos/esc_pos_renderer.dart';
import '../renderers/ticket/ticket_80mm_pdf_renderer.dart';
import '../transports/print_transport.dart';

/// Servicio central que coordina las tres salidas de un documento:
/// 1. A4 PDF formal
/// 2. Ticket térmico 80 mm PDF
/// 3. ESC/POS directo al cabezal de impresión
class DocumentService {
  const DocumentService({
    this.a4Renderer = const A4PdfRenderer(),
    this.ticketRenderer = const Ticket80mmPdfRenderer(),
    this.escPosRenderer = const EscPosRenderer(),
    this.defaultProfile = const RongtaRpp300Profile(),
  });

  final A4PdfRenderer a4Renderer;
  final Ticket80mmPdfRenderer ticketRenderer;
  final EscPosRenderer escPosRenderer;
  final PrinterProfile defaultProfile;

  /// Renderiza un documento en formato A4 PDF estándar.
  Future<PdfOutput> renderA4Pdf(DocumentModel document) {
    return a4Renderer.render(document);
  }

  /// Renderiza un documento en formato Ticket térmico de 80 mm PDF.
  Future<PdfOutput> renderTicket80mmPdf(DocumentModel document) {
    return ticketRenderer.render(document);
  }

  /// Genera los bytes de comandos ESC/POS según el perfil indicado.
  Uint8List renderEscPos(
    DocumentModel document, {
    PrinterProfile? profile,
  }) {
    return escPosRenderer.render(
      document,
      profile: profile ?? defaultProfile,
    );
  }

  /// Transmite directamente los comandos ESC/POS a través del transporte físico o simulado.
  Future<void> printEscPosDirect(
    DocumentModel document, {
    required PrintTransport transport,
    PrinterProfile? profile,
  }) async {
    final bytes = renderEscPos(document, profile: profile);
    if (!transport.isConnected) {
      await transport.connect();
    }
    await transport.send(bytes);
  }
}
