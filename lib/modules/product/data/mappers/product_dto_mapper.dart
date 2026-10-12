import '../../api/product_dtos.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';

/// Conversion entre la entidad de dominio y el DTO publico.
///
/// Vive en `data/` porque es la capa que traduce representaciones externas.
/// `domain/` no conoce `ProductSummaryDto`.
extension ProductPublicMapper on Product {
  ProductSummaryDto toSummaryDto() => ProductSummaryDto(
    id: id,
    sku: sku,
    name: name,
    description: description,
    currentStock: currentStock,
    imageUrl: imageUrl,
    barcode: barcode,
    unitPriceInCents: unitPriceInCents,
    promotionalPriceInCents: promotionPriceInCents,
    reorderPoint: reorderPoint,
    packagePriceInCents: packagePriceInCents,
    packagingPresentationId: packagingPresentationId,
    packagingPresentationName: packagingPresentationName,
    minimumSaleQuantity: minimumSaleQuantity,
    unitsPerPresentation: unitsPerPresentation,
    minimumOrderQuantity: minimumOrderQuantity,
  );
}

/// La consulta publica solo traslada los filtros que el contrato expone.
extension ProductListQueryMapper on ProductListQuery {
  ProductQuery toDomainQuery() => ProductQuery(
    searchTerm: searchTerm,
    categoryId: categoryId,
    isActive: isActive,
  );
}
