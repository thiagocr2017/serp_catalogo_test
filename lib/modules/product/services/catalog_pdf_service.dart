import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/entities/product.dart';

enum CatalogImageFit { contain, cover, fitWidth }

List<Product> eligibleCatalogProducts(Iterable<Product> products) => products
    .where((product) => product.isActive && !product.isOutOfStock)
    .toList();

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
    this.highlightTextColor = '#1565C0',
    this.secondaryTextColor = '#616161',
    this.promotionColor = '#C62828',
    this.promotionTextColor = '#FFFFFF',
    this.promotionPreviousPriceColor = '#757575',
    this.promotionPriceColor = '#C62828',
    this.promotionDescriptionColor = '#C62828',
    this.imageFit = CatalogImageFit.cover,
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
  final String highlightTextColor;
  final String secondaryTextColor;
  final String promotionColor;
  final String promotionTextColor;
  final String promotionPreviousPriceColor;
  final String promotionPriceColor;
  final String promotionDescriptionColor;
  final CatalogImageFit imageFit;
}

/// Carga los bytes de una fuente tipográfica empaquetada como asset.
///
/// La app Flutter inyecta `rootBundle.load`; las herramientas de desarrollo
/// (Dart puro) usan la lectura por defecto desde disco.
typedef PdfFontLoader = Future<ByteData> Function(String assetPath);

class CatalogPdfService {
  static const _unicodeFontAssets = [
    'assets/fonts/Roboto-Regular.ttf',
    'assets/fonts/Roboto-Bold.ttf',
    'assets/fonts/Roboto-Italic.ttf',
    'assets/fonts/Roboto-BoldItalic.ttf',
  ];

  static Future<ByteData> _diskFontLoader(String assetPath) async {
    final bytes = await File(assetPath).readAsBytes();
    return ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
  }

  /// Sustituye las fuentes estándar (Helvetica/Courier, sin Unicode) por
  /// Roboto en todos los estilos por defecto del documento: cuerpo, negritas,
  /// cursivas, encabezados y tablas. Sin este cambio, los caracteres fuera
  /// del conjunto WinAnsi (→, •, emojis, etc.) se pierden al generar el PDF.
  static Future<void> _installUnicodeFonts(PdfFontLoader loader) async {
    final fonts = await Future.wait(_unicodeFontAssets.map(loader));
    pw.ThemeData.buildThemeData = () => pw.ThemeData.withFont(
      base: pw.Font.ttf(fonts[0]),
      bold: pw.Font.ttf(fonts[1]),
      italic: pw.Font.ttf(fonts[2]),
      boldItalic: pw.Font.ttf(fonts[3]),
    );
  }

  Future<Uint8List> generate(
    List<Product> products,
    CatalogPdfOptions options, {
    PdfFontLoader fontLoader = _diskFontLoader,
  }) async {
    products = eligibleCatalogProducts(products);
    await _installUnicodeFonts(fontLoader);
    final background = PdfColor.fromHex(options.backgroundColor);
    final card = PdfColor.fromHex(options.cardColor);
    final accent = PdfColor.fromHex(options.accentColor);
    final textColor = PdfColor.fromHex(options.textColor);
    final highlightText = PdfColor.fromHex(options.highlightTextColor);
    final secondaryText = PdfColor.fromHex(options.secondaryTextColor);
    final promotion = PdfColor.fromHex(options.promotionColor);
    final promotionText = PdfColor.fromHex(options.promotionTextColor);
    final promotionPreviousPrice = PdfColor.fromHex(
      options.promotionPreviousPriceColor,
    );
    final promotionPrice = PdfColor.fromHex(options.promotionPriceColor);
    final promotionDescription = PdfColor.fromHex(
      options.promotionDescriptionColor,
    );
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
                    width: 300,
                    height: 190,
                    child: pw.Image(
                      pw.MemoryImage(options.logoBytes!),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                ],
                pw.Text(
                  options.companyName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.normal,
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
                  // El QR no dibuja texto; desactivarlo evita que se registre
                  // la fuente Courier (sin Unicode) en el documento.
                  drawText: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final compact = options.cardsPerPage == 0;
    if (!compact) {
      final perPage = options.cardsPerPage;
      final groups = <String, List<Product>>{};
      for (final product in products) {
        groups.putIfAbsent(product.categoryId, () => []).add(product);
      }
      var pageNumber = 2;
      for (final entry in groups.entries) {
        for (var start = 0; start < entry.value.length; start += perPage) {
          final end = (start + perPage).clamp(0, entry.value.length);
          document.addPage(
            _productsPage(
              entry.value.sublist(start, end),
              categoryName: options.categoryNames[entry.key] ?? 'Sin categoría',
              options: options,
              images: images,
              backgroundColor: background,
              cardColor: card,
              accentColor: accent,
              textColor: textColor,
              highlightTextColor: highlightText,
              secondaryTextColor: secondaryText,
              promotionColor: promotion,
              promotionTextColor: promotionText,
              promotionPreviousPriceColor: promotionPreviousPrice,
              promotionPriceColor: promotionPrice,
              promotionDescriptionColor: promotionDescription,
              pageNumber: pageNumber++,
            ),
          );
        }
      }
      return document.save();
    }
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
                    highlightTextColor: highlightText,
                    secondaryTextColor: secondaryText,
                    promotionColor: promotion,
                    promotionTextColor: promotionText,
                    promotionPreviousPriceColor: promotionPreviousPrice,
                    promotionPriceColor: promotionPrice,
                    promotionDescriptionColor: promotionDescription,
                    packagingLabel: product.packagingPresentationName,
                    imageFit: options.imageFit,
                  ),
                ),
            ],
          ];
        },
      ),
    );
    return document.save();
  }

  pw.Page _productsPage(
    List<Product> products, {
    required String categoryName,
    required CatalogPdfOptions options,
    required Map<String, pw.ImageProvider> images,
    required PdfColor backgroundColor,
    required PdfColor cardColor,
    required PdfColor accentColor,
    required PdfColor textColor,
    required PdfColor highlightTextColor,
    required PdfColor secondaryTextColor,
    required PdfColor promotionColor,
    required PdfColor promotionTextColor,
    required PdfColor promotionPreviousPriceColor,
    required PdfColor promotionPriceColor,
    required PdfColor promotionDescriptionColor,
    required int pageNumber,
  }) {
    final perPage = options.cardsPerPage;
    final columns = perPage == 1 || perPage == 2 ? 1 : 2;
    final rows = perPage == 1
        ? 1
        : perPage == 2
        ? 2
        : perPage == 4
        ? 2
        : 3;
    final imageHeight = switch (perPage) {
      1 => 430.0,
      2 => 205.0,
      4 => 160.0,
      _ => 92.0,
    };

    return pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData(defaultTextStyle: pw.TextStyle(color: textColor)),
        buildBackground: (_) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: backgroundColor),
        ),
      ),
      build: (_) => pw.Column(
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
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: accentColor,
            child: pw.Text(
              categoryName,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Expanded(
            child: pw.Column(
              children: [
                for (var row = 0; row < rows; row++) ...[
                  if (row > 0) pw.SizedBox(height: 10),
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        for (var column = 0; column < columns; column++) ...[
                          if (column > 0) pw.SizedBox(width: 10),
                          pw.Expanded(
                            child: row * columns + column < products.length
                                ? _card(
                                    products[row * columns + column],
                                    image:
                                        images[products[row * columns + column]
                                            .id],
                                    compact: false,
                                    horizontal: perPage == 2,
                                    imageHeight: imageHeight,
                                    cardColor: cardColor,
                                    accentColor: accentColor,
                                    textColor: textColor,
                                    highlightTextColor: highlightTextColor,
                                    secondaryTextColor: secondaryTextColor,
                                    promotionColor: promotionColor,
                                    promotionTextColor: promotionTextColor,
                                    promotionPreviousPriceColor:
                                        promotionPreviousPriceColor,
                                    promotionPriceColor: promotionPriceColor,
                                    promotionDescriptionColor:
                                        promotionDescriptionColor,
                                    packagingLabel:
                                        products[row * columns + column]
                                            .packagingPresentationName,
                                    imageFit: options.imageFit,
                                  )
                                : pw.SizedBox(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Página $pageNumber'),
          ),
        ],
      ),
    );
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
    bool horizontal = false,
    double? imageHeight,
    String? categoryName,
    required PdfColor cardColor,
    required PdfColor accentColor,
    required PdfColor textColor,
    PdfColor? highlightTextColor,
    PdfColor? secondaryTextColor,
    PdfColor? promotionColor,
    PdfColor? promotionTextColor,
    PdfColor? promotionPreviousPriceColor,
    PdfColor? promotionPriceColor,
    PdfColor? promotionDescriptionColor,
    String? packagingLabel,
    CatalogImageFit imageFit = CatalogImageFit.cover,
  }) {
    final highlight = highlightTextColor ?? accentColor;
    final secondary = secondaryTextColor ?? PdfColors.grey700;
    final promoBackground = promotionColor ?? accentColor;
    final promoText = promotionTextColor ?? PdfColors.white;
    final previousPrice = promotionPreviousPriceColor ?? secondary;
    final currentPromotionPrice = promotionPriceColor ?? promoBackground;
    final promotionDescription =
        promotionDescriptionColor ?? currentPromotionPrice;
    final hasPromotion = product.promotionPriceInCents != null;
    final finalPrice = hasPromotion
        ? product.promotionPriceInCents!
        : product.unitPriceInCents;
    final dense = (imageHeight ?? 999) < 110;
    if (horizontal) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: cardColor,
          border: pw.Border.all(color: accentColor),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Expanded(
              flex: 11,
              child: image == null
                  ? pw.SizedBox()
                  : pw.ClipRect(
                      child: pw.Transform.translate(
                        offset: PdfPoint(
                          (product.imagePositionX - .5) * 180,
                          (product.imagePositionY - .5) * 180,
                        ),
                        child: pw.Transform.scale(
                          scale: product.imageScale,
                          child: pw.Image(image, fit: _pdfImageFit(imageFit)),
                        ),
                      ),
                    ),
            ),
            pw.SizedBox(width: 18),
            pw.Expanded(
              flex: 9,
              child: pw.DefaultTextStyle(
                style: pw.TextStyle(color: textColor),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          product.sku,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: highlight,
                          ),
                        ),
                        if (hasPromotion)
                          pw.Container(
                            color: promoBackground,
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: pw.Text(
                              'OFERTA',
                              style: pw.TextStyle(
                                color: promoText,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      product.name,
                      maxLines: 2,
                      style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 7),
                    pw.Text(product.description, maxLines: 4),
                    pw.Spacer(),
                    pw.Text(
                      'Presentación ${packagingLabel ?? 'No disponible'} - Venta mínima ${product.minimumSaleQuantity}',
                      style: pw.TextStyle(fontSize: 9, color: secondary),
                    ),
                    if (hasPromotion)
                      pw.Text(
                        'Antes: USD ${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: previousPrice,
                          decoration: pw.TextDecoration.lineThrough,
                        ),
                      ),
                    pw.Text(
                      'USD ${(finalPrice / 100).toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: hasPromotion ? currentPromotionPrice : textColor,
                      ),
                    ),
                    if (product.promotionText != null)
                      pw.Text(
                        product.promotionText!,
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: promotionDescription,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: cardColor,
        border: pw.Border.all(color: accentColor),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.DefaultTextStyle(
        style: pw.TextStyle(color: textColor),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (categoryName != null) ...[
              pw.Text(
                categoryName.toUpperCase(),
                maxLines: 1,
                style: pw.TextStyle(
                  color: highlight,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
            ],
            if (image != null && !compact) ...[
              pw.Container(
                height: imageHeight ?? 90,
                width: double.infinity,
                child: pw.ClipRect(
                  child: pw.Transform.translate(
                    offset: PdfPoint(
                      (product.imagePositionX - .5) * 180,
                      (product.imagePositionY - .5) *
                          ((imageHeight ?? 90) * .9),
                    ),
                    child: pw.Transform.scale(
                      scale: product.imageScale,
                      child: pw.Image(image, fit: _pdfImageFit(imageFit)),
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: dense ? 4 : 8),
            ],
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  product.sku,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: highlight,
                  ),
                ),
                if (hasPromotion)
                  pw.Container(
                    color: promoBackground,
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: pw.Text(
                      'OFERTA',
                      style: pw.TextStyle(color: promoText, fontSize: 9),
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: dense ? 3 : 8),
            pw.Text(
              product.name,
              maxLines: dense ? 1 : 2,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: dense ? 12 : 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (!dense) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                product.description,
                maxLines: imageHeight != null && imageHeight > 300 ? 4 : 2,
                overflow: pw.TextOverflow.clip,
              ),
            ],
            if (compact) pw.SizedBox(height: 6) else pw.Spacer(),
            pw.Text(
              'Presentación ${packagingLabel ?? 'No disponible'} - Venta mínima ${product.minimumSaleQuantity}',
              maxLines: 1,
              style: pw.TextStyle(fontSize: dense ? 7 : 9, color: secondary),
            ),
            if (hasPromotion)
              pw.Text(
                'Antes: USD ${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: previousPrice,
                  decoration: pw.TextDecoration.lineThrough,
                ),
              ),
            pw.Text(
              'USD ${(finalPrice / 100).toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: dense ? 14 : 18,
                fontWeight: pw.FontWeight.bold,
                color: hasPromotion ? currentPromotionPrice : textColor,
              ),
            ),
            if (product.promotionText != null)
              pw.Text(
                product.promotionText!,
                style: pw.TextStyle(fontSize: 8, color: promotionDescription),
              ),
          ],
        ),
      ),
    );
  }

  pw.BoxFit _pdfImageFit(CatalogImageFit fit) => switch (fit) {
    CatalogImageFit.contain => pw.BoxFit.contain,
    CatalogImageFit.cover => pw.BoxFit.cover,
    CatalogImageFit.fitWidth => pw.BoxFit.fitWidth,
  };
}
