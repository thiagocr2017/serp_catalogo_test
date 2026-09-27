import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/entities/product.dart';

class CatalogPdfOptions {
  const CatalogPdfOptions({
    required this.companyName,
    required this.paymentMethods,
    required this.agentName,
    required this.agentPhone,
    required this.cardsPerPage,
    this.categoryNames = const {},
    this.logoBytes,
    this.backgroundColor = '#FFFFFF',
    this.cardColor = '#FFFFFF',
    this.accentColor = '#3949AB',
    this.textColor = '#111111',
  });
  final String companyName;
  final String paymentMethods;
  final String agentName;
  final String agentPhone;
  final int cardsPerPage;
  final Map<String, String> categoryNames;
  final Uint8List? logoBytes;
  final String backgroundColor;
  final String cardColor;
  final String accentColor;
  final String textColor;
}

class CatalogPdfService {
  Future<Uint8List> generate(
    List<Product> products,
    CatalogPdfOptions options,
  ) async {
    final background = PdfColor.fromHex(options.backgroundColor);
    final card = PdfColor.fromHex(options.cardColor);
    final accent = PdfColor.fromHex(options.accentColor);
    final textColor = PdfColor.fromHex(options.textColor);
    final images = <String, pw.ImageProvider>{};
    for (final product in products) {
      final url = product.imageUrl;
      if (url == null || url.isEmpty) continue;
      try {
        images[product.id] = pw.MemoryImage(await _download(url));
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
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          theme: pw.ThemeData(defaultTextStyle: pw.TextStyle(color: textColor)),
        ),
        build: (_) => pw.Container(
          width: double.infinity,
          height: double.infinity,
          color: background,
          padding: const pw.EdgeInsets.all(42),
          child: pw.DefaultTextStyle(
            style: pw.TextStyle(color: textColor),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (options.logoBytes != null) ...[
                  pw.Container(
                    width: 150,
                    height: 90,
                    child: pw.Image(
                      pw.MemoryImage(options.logoBytes!),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  pw.SizedBox(height: 18),
                ],
                pw.Text(
                  options.companyName,
                  style: pw.TextStyle(
                    fontSize: 34,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 18),
                pw.Text(
                  'CATÁLOGO DE PRODUCTOS',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 20, color: accent),
                ),
                pw.SizedBox(height: 40),
                pw.Container(
                  width: 360,
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
        ),
      ),
    );
    if (options.cardsPerPage == 1) {
      for (final product in products) {
        document.addPage(
          pw.Page(
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(28),
              theme: pw.ThemeData(
                defaultTextStyle: pw.TextStyle(color: textColor),
              ),
              buildBackground: (_) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Container(color: background),
              ),
            ),
            build: (_) => pw.Container(
              width: double.infinity,
              height: double.infinity,
              color: background,
              child: pw.DefaultTextStyle(
                style: pw.TextStyle(color: textColor),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          options.companyName,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text('Catálogo'),
                      ],
                    ),
                    pw.SizedBox(height: 18),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      color: accent,
                      child: pw.Text(
                        options.categoryNames[product.categoryId] ??
                            'Sin categoría',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 14),
                    pw.Expanded(
                      child: _card(
                        product,
                        image: images[product.id],
                        compact: false,
                        cardColor: card,
                        accentColor: accent,
                        textColor: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return document.save();
    }
    final compact = options.cardsPerPage == 0;
    final columns = compact
        ? 1
        : options.cardsPerPage <= 4
        ? 2
        : 3;
    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData(defaultTextStyle: pw.TextStyle(color: textColor)),
          buildBackground: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: background),
          ),
        ),
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
                color: accent,
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
                      cardColor: card,
                      accentColor: accent,
                      textColor: textColor,
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
                      _card(
                        product,
                        image: images[product.id],
                        compact: false,
                        cardColor: card,
                        accentColor: accent,
                        textColor: textColor,
                      ),
                  ],
                ),
            ],
          ];
        },
      ),
    );
    return document.save();
  }

  Future<Uint8List> _download(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Image request failed: ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      return Uint8List.fromList(bytes);
    } finally {
      client.close(force: true);
    }
  }

  pw.Widget _card(
    Product product, {
    pw.ImageProvider? image,
    required bool compact,
    required PdfColor cardColor,
    required PdfColor accentColor,
    required PdfColor textColor,
  }) {
    final hasPromotion = product.promotionPriceInCents != null;
    final finalPrice = hasPromotion
        ? product.promotionPriceInCents!
        : product.unitPriceInCents;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: cardColor,
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.DefaultTextStyle(
        style: pw.TextStyle(color: textColor),
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
                    color: accentColor,
                  ),
                ),
                if (hasPromotion)
                  pw.Container(
                    color: accentColor,
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
              'Presentación ${product.packagingType.name.toUpperCase()} - Venta mínima ${product.minimumSaleQuantity}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
            if (hasPromotion)
              pw.Text(
                'Antes: USD ${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  decoration: pw.TextDecoration.lineThrough,
                ),
              ),
            pw.Text(
              'USD ${(finalPrice / 100).toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: hasPromotion ? accentColor : textColor,
              ),
            ),
            if (product.promotionText != null)
              pw.Text(
                product.promotionText!,
                style: pw.TextStyle(fontSize: 8, color: accentColor),
              ),
          ],
        ),
      ),
    );
  }
}
