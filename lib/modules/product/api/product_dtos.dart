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
/// cambio (`MODULE_SECURITY_CONTRACT.md` §3).
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
  });

  final String id;
  final String sku;
  final String name;
  final String description;
  final int currentStock;

  @override
  bool operator ==(Object other) =>
      other is ProductSummaryDto &&
      other.id == id &&
      other.sku == sku &&
      other.name == name &&
      other.description == description &&
      other.currentStock == currentStock;

  @override
  int get hashCode => Object.hash(id, sku, name, description, currentStock);

  @override
  String toString() =>
      'ProductSummaryDto(id: $id, sku: $sku, name: $name, '
      'description: $description, currentStock: $currentStock)';
}
