import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/entities/product.dart';

class CatalogPdfOptions {
  const CatalogPdfOptions({
    required this.companyName,
    required this.paymentMethods,
    required this.agentName,
    required this.agentPhone,
    required this.cardsPerPage,
    this.categoryNames = const {},
  });
  final String companyName;
  final String paymentMethods;
  final String agentName;
  final String agentPhone;
  final int cardsPerPage;
  final Map<String, String> categoryNames;
}

class CatalogPdfService {
  Future<Uint8List> generate(
    List<Product> products,
    CatalogPdfOptions options,
  ) async {
    final images = <String, pw.ImageProvider>{};
    for (final product in products) {
      final url = product.imageUrl;
      if (url == null || url.isEmpty) continue;
      try {
        images[product.id] = await networkImage(url);
      } catch (_) {
        // El catálogo sigue siendo utilizable si una imagen remota no responde.
      }
    }
    final document = pw.Document(
      title: 'Catálogo ${options.companyName}',
      author: options.agentName,
    );
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              options.companyName,
              style: pw.TextStyle(fontSize: 34, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'CATÁLOGO DE PRODUCTOS',
              style: const pw.TextStyle(
                fontSize: 20,
                color: PdfColors.indigo700,
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Métodos de pago',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    options.paymentMethods,
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text('Agente: ${options.agentName}'),
            pw.Text(options.agentPhone),
            pw.SizedBox(height: 12),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data:
                  'https://wa.me/${options.agentPhone.replaceAll(RegExp(r'[^0-9]'), '')}',
              width: 90,
              height: 90,
            ),
          ],
        ),
      ),
    );
    final compact = options.cardsPerPage == 0;
    final columns = compact || options.cardsPerPage == 1
        ? 1
        : options.cardsPerPage <= 4
        ? 2
        : 3;
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              options.companyName,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Catálogo'),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
          ),
        ),
        build: (_) {
          final groups = <String, List<Product>>{};
          for (final product in products) {
            groups.putIfAbsent(product.categoryId, () => []).add(product);
          }
          return [
            for (final entry in groups.entries) ...[
              pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(top: 12, bottom: 10),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                color: PdfColors.indigo700,
                child: pw.Text(
                  options.categoryNames[entry.key] ?? 'Sin categoría',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (compact)
                for (final product in entry.value)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: _card(
                      product,
                      image: images[product.id],
                      compact: true,
                    ),
                  )
              else
                pw.GridView(
                  crossAxisCount: columns,
                  childAspectRatio: options.cardsPerPage == 1 ? 1.8 : 1.15,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    for (final product in entry.value)
                      _card(product, image: images[product.id], compact: false),
                  ],
                ),
            ],
          ];
        },
      ),
    );
    return document.save();
  }

  pw.Widget _card(
    Product product, {
    pw.ImageProvider? image,
    required bool compact,
  }) {
    final hasPromotion = product.promotionPriceInCents != null;
    final finalPrice = hasPromotion
        ? product.promotionPriceInCents!
        : product.unitPriceInCents;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (image != null && !compact) ...[
            pw.Container(
              height: 90,
              width: double.infinity,
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 8),
          ],
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                product.sku,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo700,
                ),
              ),
              if (hasPromotion)
                pw.Container(
                  color: PdfColors.red,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  child: pw.Text(
                    'OFERTA',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            product.name,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            product.description,
            maxLines: 3,
            overflow: pw.TextOverflow.clip,
          ),
          if (compact) pw.SizedBox(height: 6) else pw.Spacer(),
          pw.Text(
            'Se vende en ${product.packagingType.name.toUpperCase()} - MOQ ${product.minimumOrderQuantity}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          if (hasPromotion)
            pw.Text(
              'Antes: USD ${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          pw.Text(
            'USD ${(finalPrice / 100).toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: hasPromotion ? PdfColors.red700 : PdfColors.black,
            ),
          ),
          if (product.promotionText != null)
            pw.Text(
              product.promotionText!,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.red700),
            ),
        ],
      ),
    );
  }
}
