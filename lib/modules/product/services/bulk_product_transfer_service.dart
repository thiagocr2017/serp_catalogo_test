import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:image/image.dart' as image;
import 'package:uuid/uuid.dart';

import '../domain/entities/category.dart';
import '../domain/entities/product.dart';
import '../domain/repositories/product_repository.dart';
import '../../configuration/configuration_module.dart';
import 'product_image_service.dart';

class BulkProductTransferService {
  const BulkProductTransferService(this._repository, this._imageService);

  final ProductRepository _repository;
  final ProductImageService _imageService;

  static const headers = [
    'sku',
    'nombre',
    'descripcion',
    'categoria',
    'codigo_barras',
    'precio_unitario',
    'precio_empaque',
    'venta_minima',
    'presentacion',
    'moq_recompra',
    'cbm_por_moq',
    'costo_fabrica',
    'stock_inicial',
    'punto_reorden',
    'activo',
    'imagen',
  ];

  String templateCsv() => excel.encode([headers]);

  String exportCsv(List<Product> products, List<Category> categories) {
    final categoryNames = {for (final c in categories) c.id: c.name};
    return excel.encode([
      headers,
      for (final product in products)
        [
          product.sku,
          product.name,
          product.description,
          categoryNames[product.categoryId] ?? '',
          product.barcode ?? '',
          product.unitPriceInCents / 100,
          product.packagePriceInCents == null
              ? ''
              : product.packagePriceInCents! / 100,
          product.minimumSaleQuantity,
          product.packagingPresentationName ?? 'Sin presentación',
          product.minimumOrderQuantity,
          product.cbmPerMoq,
          product.factoryCostInCents / 100,
          product.currentStock,
          product.reorderPoint,
          product.isActive ? 'SI' : 'NO',
          product.imageUrl == null ? '' : '${product.sku}.JPG',
        ],
    ]);
  }

  BulkProductPreview parseCsv(
    String text, {
    required List<Category> categories,
    required List<Product> existingProducts,
    List<PackagingPresentationDto> presentations = const [],
  }) {
    final rows = csv.decode(text);
    if (rows.isEmpty) {
      return const BulkProductPreview(
        rows: [],
        errors: ['El archivo está vacío.'],
      );
    }
    final normalizedHeaders = rows.first
        .map(
          (value) =>
              value.toString().replaceFirst('\ufeff', '').trim().toLowerCase(),
        )
        .toList();
    final missing = headers.where(
      (header) => !normalizedHeaders.contains(header),
    );
    if (missing.isNotEmpty) {
      return BulkProductPreview(
        rows: const [],
        errors: ['Faltan columnas: ${missing.join(', ')}.'],
      );
    }
    final indexes = {
      for (final header in headers) header: normalizedHeaders.indexOf(header),
    };
    final categoryByName = {
      for (final category in categories)
        category.name.trim().toLowerCase(): category,
    };
    final existingBySku = {
      for (final product in existingProducts)
        product.sku.trim().toLowerCase(): product,
    };
    final presentationByName = {
      for (final presentation in presentations)
        presentation.name.trim().toLowerCase(): presentation,
    };
    final parsed = <BulkProductRow>[];
    final errors = <String>[];
    for (var index = 1; index < rows.length; index++) {
      final source = rows[index];
      String value(String header) {
        final column = indexes[header]!;
        return column < source.length ? source[column].toString().trim() : '';
      }

      final line = index + 1;
      final sku = value('sku');
      final name = value('nombre');
      final category = categoryByName[value('categoria').toLowerCase()];
      if (sku.isEmpty || name.isEmpty || category == null) {
        errors.add(
          'Fila $line: SKU, nombre y una categoría existente son obligatorios.',
        );
        continue;
      }
      try {
        final presentation =
            presentationByName[value('presentacion').toLowerCase()];
        if (presentation == null) {
          errors.add(
            'Fila $line: la presentación "${value('presentacion')}" no existe.',
          );
          continue;
        }
        parsed.add(
          BulkProductRow(
            line: line,
            existing: existingBySku[sku.toLowerCase()],
            sku: sku,
            name: name,
            description: value('descripcion'),
            categoryId: category.id,
            barcode: _nullable(value('codigo_barras')),
            unitPriceInCents: _cents(value('precio_unitario')),
            packagePriceInCents: value('precio_empaque').isEmpty
                ? null
                : _cents(value('precio_empaque')),
            minimumSaleQuantity: _positiveInt(
              value('venta_minima'),
              fallback: 1,
            ),
            packagingPresentationId: presentation.id,
            packagingPresentationName: presentation.name,
            minimumOrderQuantity: _positiveInt(
              value('moq_recompra'),
              fallback: 1,
            ),
            cbmPerMoq: _decimal(value('cbm_por_moq'), fallback: 0),
            factoryCostInCents: _cents(value('costo_fabrica'), fallback: 0),
            initialStock: int.tryParse(value('stock_inicial')) ?? 0,
            reorderPoint: int.tryParse(value('punto_reorden')) ?? 0,
            isActive: !const {
              'NO',
              'FALSE',
              '0',
              'INACTIVO',
            }.contains(value('activo').toUpperCase()),
            imageName: _nullable(value('imagen')),
          ),
        );
      } catch (error) {
        errors.add('Fila $line: datos numéricos inválidos ($error).');
      }
    }
    return BulkProductPreview(rows: parsed, errors: errors);
  }

  Map<String, Uint8List> readImageZip(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final result = <String, Uint8List>{};
    for (final file in archive) {
      if (!file.isFile || !_isImage(file.name)) {
        continue;
      }
      final decoded = image.decodeImage(file.content);
      if (decoded == null) {
        continue;
      }
      final resized = decoded.width > 1600
          ? image.copyResize(decoded, width: 1600)
          : decoded;
      result[_baseName(file.name).toLowerCase()] = Uint8List.fromList(
        image.encodeJpg(resized, quality: 82),
      );
    }
    return result;
  }

  Future<BulkImportResult> import(
    BulkProductPreview preview, {
    Map<String, Uint8List> images = const {},
  }) async {
    var created = 0;
    var updated = 0;
    final errors = <String>[];
    for (final row in preview.rows) {
      try {
        final existing = row.existing;
        final imageKey = (row.imageName ?? '${row.sku}.JPG').toLowerCase();
        final imageBytes = images[imageKey];
        final imageUrl = imageBytes == null
            ? existing?.imageUrl
            : await _imageService.replace(
                sku: row.sku,
                bytes: imageBytes,
                previousUrl: existing?.imageUrl,
              );
        final product = Product(
          id: existing?.id ?? const Uuid().v4(),
          sku: row.sku,
          barcode: row.barcode,
          name: row.name,
          description: row.description,
          categoryId: row.categoryId,
          unitPriceInCents: row.unitPriceInCents,
          packagePriceInCents: row.packagePriceInCents,
          minimumOrderQuantity: row.minimumOrderQuantity,
          minimumSaleQuantity: row.minimumSaleQuantity,
          packagingPresentationId: row.packagingPresentationId,
          packagingPresentationName:
              row.packagingPresentationName ??
              existing?.packagingPresentationName,
          cbmPerMoq: row.cbmPerMoq,
          factoryCostInCents: row.factoryCostInCents,
          imageUrl: imageUrl,
          imagePositionX: existing?.imagePositionX ?? .5,
          imagePositionY: existing?.imagePositionY ?? .5,
          imageScale: existing?.imageScale ?? 1,
          catalogSortOrder: existing?.catalogSortOrder ?? 0,
          currentStock: existing?.currentStock ?? 0,
          reorderPoint: row.reorderPoint,
          promotionPriceInCents: existing?.promotionPriceInCents,
          promotionText: existing?.promotionText,
          promotionType: existing?.promotionType,
          isActive: row.isActive,
          createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
          updatedAt: existing == null ? null : DateTime.now().toUtc(),
        );
        if (existing == null) {
          await _repository.createProduct(
            product,
            initialStock: row.initialStock,
          );
          created++;
        } else {
          await _repository.updateProduct(product);
          updated++;
        }
      } catch (error) {
        errors.add('Fila ${row.line} (${row.sku}): $error');
      }
    }
    return BulkImportResult(created: created, updated: updated, errors: errors);
  }

  Future<Uint8List> exportImagesZip(List<Product> products) async {
    final archive = Archive();
    final client = HttpClient();
    try {
      for (final product in products.where((p) => p.imageUrl != null)) {
        final request = await client.getUrl(Uri.parse(product.imageUrl!));
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          continue;
        }
        final bytes = await response.fold<List<int>>(
          [],
          (all, chunk) => all..addAll(chunk),
        );
        archive.addFile(ArchiveFile('${product.sku}.JPG', bytes.length, bytes));
      }
    } finally {
      client.close();
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static String? _nullable(String value) => value.isEmpty ? null : value;
  static double _decimal(String value, {required double fallback}) =>
      value.isEmpty ? fallback : double.parse(value.replaceAll(',', '.'));
  static int _cents(String value, {int fallback = 0}) =>
      value.isEmpty ? fallback : (_decimal(value, fallback: 0) * 100).round();
  static int _positiveInt(String value, {required int fallback}) {
    final parsed = value.isEmpty ? fallback : int.parse(value);
    if (parsed <= 0) {
      throw const FormatException('la cantidad debe ser mayor que cero');
    }
    return parsed;
  }

  static bool _isImage(String name) =>
      RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false).hasMatch(name);
  static String _baseName(String path) => path.split('/').last;
}

class BulkProductPreview {
  const BulkProductPreview({required this.rows, required this.errors});
  final List<BulkProductRow> rows;
  final List<String> errors;
}

class BulkProductRow {
  const BulkProductRow({
    required this.line,
    required this.existing,
    required this.sku,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.barcode,
    required this.unitPriceInCents,
    required this.packagePriceInCents,
    required this.minimumSaleQuantity,
    required this.packagingPresentationId,
    this.packagingPresentationName,
    required this.minimumOrderQuantity,
    required this.cbmPerMoq,
    required this.factoryCostInCents,
    required this.initialStock,
    required this.reorderPoint,
    required this.isActive,
    required this.imageName,
  });
  final int line;
  final Product? existing;
  final String sku;
  final String name;
  final String description;
  final String categoryId;
  final String? barcode;
  final int unitPriceInCents;
  final int? packagePriceInCents;
  final int minimumSaleQuantity;
  final String packagingPresentationId;
  final String? packagingPresentationName;
  final int minimumOrderQuantity;
  final double cbmPerMoq;
  final int factoryCostInCents;
  final int initialStock;
  final int reorderPoint;
  final bool isActive;
  final String? imageName;
}

class BulkImportResult {
  const BulkImportResult({
    required this.created,
    required this.updated,
    required this.errors,
  });
  final int created;
  final int updated;
  final List<String> errors;
}
