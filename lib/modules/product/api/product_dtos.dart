import 'package:flutter/foundation.dart';

/// Consulta publica de listado de productos.
///
/// Es un tipo de valor compartido, no una entidad de dominio. A proposito no
/// expone `onlyLowStock`, `minimumPriceInCents` ni `maximumPriceInCents`:
/// son filtros internos de `domain/entities/product_query.dart` y exponerlos
/// haria que un cambio interno de esos filtros rompiera el contrato publico.
@immutable
class ProductListQuery {
  const ProductListQuery({this.searchTerm, this.categoryId, this.isActive});

  final String? searchTerm;
  final String? categoryId;
  final bool? isActive;

  @override
  bool operator ==(Object other) =>
      other is ProductListQuery &&
      other.searchTerm == searchTerm &&
      other.categoryId == categoryId &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(searchTerm, categoryId, isActive);

  @override
  String toString() =>
      'ProductListQuery(searchTerm: $searchTerm, categoryId: $categoryId, '
      'isActive: $isActive)';
}

/// Resumen de producto expuesto a otros modulos.
///
/// DTO publico inmutable y estable: solo los campos que el consumidor necesita.
/// Quitar o reinterpretar un campo exige migrar consumidores y registrar el
/// cambio (`.specs/architecture/module-security-contract.md` §3).
///
/// Los identificadores son opacos: el consumidor los devuelve tal cual y no
/// debe derivar nada de su estructura.
@immutable
class ProductSummaryDto {
  const ProductSummaryDto({
    required this.id,
    required this.sku,
    required this.name,
    required this.description,
    required this.currentStock,
    this.imageUrl,
    this.barcode,
    this.unitPriceInCents = 0,
    this.promotionalPriceInCents,
    this.reorderPoint = 0,
    this.packagePriceInCents,
    this.packagingPresentationId,
    this.packagingPresentationName,
    this.minimumSaleQuantity = 1,
    this.unitsPerPresentation = 1,
    this.minimumOrderQuantity = 1,
  });

  final String id;
  final String sku;
  final String name;
  final String description;
  final int currentStock;
  final String? imageUrl;
  final String? barcode;
  final int unitPriceInCents;
  final int? promotionalPriceInCents;
  final int reorderPoint;
  final int? packagePriceInCents;
  final String? packagingPresentationId;
  final String? packagingPresentationName;
  final int minimumSaleQuantity;
  final int unitsPerPresentation;
  final int minimumOrderQuantity;

  @override
  bool operator ==(Object other) =>
      other is ProductSummaryDto &&
      other.id == id &&
      other.sku == sku &&
      other.name == name &&
      other.description == description &&
      other.currentStock == currentStock &&
      other.imageUrl == imageUrl &&
      other.barcode == barcode &&
      other.unitPriceInCents == unitPriceInCents &&
      other.promotionalPriceInCents == promotionalPriceInCents &&
      other.reorderPoint == reorderPoint &&
      other.packagePriceInCents == packagePriceInCents &&
      other.packagingPresentationId == packagingPresentationId &&
      other.packagingPresentationName == packagingPresentationName &&
      other.minimumSaleQuantity == minimumSaleQuantity &&
      other.unitsPerPresentation == unitsPerPresentation &&
      other.minimumOrderQuantity == minimumOrderQuantity;

  @override
  int get hashCode => Object.hash(
    id,
    sku,
    name,
    description,
    currentStock,
    imageUrl,
    barcode,
    unitPriceInCents,
    promotionalPriceInCents,
    reorderPoint,
    packagePriceInCents,
    packagingPresentationId,
    packagingPresentationName,
    minimumSaleQuantity,
    unitsPerPresentation,
    minimumOrderQuantity,
  );

  @override
  String toString() =>
      'ProductSummaryDto(id: $id, sku: $sku, name: $name, '
      'description: $description, currentStock: $currentStock, '
      'imageUrl: $imageUrl, barcode: $barcode, '
      'unitPriceInCents: $unitPriceInCents, '
      'promotionalPriceInCents: $promotionalPriceInCents, '
      'reorderPoint: $reorderPoint, '
      'packagePriceInCents: $packagePriceInCents, '
      'packagingPresentationName: $packagingPresentationName, '
      'minimumSaleQuantity: $minimumSaleQuantity, '
      'unitsPerPresentation: $unitsPerPresentation, '
      'minimumOrderQuantity: $minimumOrderQuantity)';
}
