/// Contratos de lectura públicos de Configuración.
///
/// Los valores decimales persistentes se transportan como texto decimal
/// normalizado; PostgreSQL los convertirá a `numeric` en las RPC de 1B.2.
class BusinessSettingsDto {
  const BusinessSettingsDto({
    required this.defaultCurrency,
    required this.decimalPlaces,
    required this.taxPercentage,
    required this.pricesIncludeTax,
    required this.roundingMode,
    required this.roundingIncrement,
    required this.companyName,
    required this.paymentMethods,
    required this.version,
  });

  final String defaultCurrency;
  final int decimalPlaces;
  final String taxPercentage;
  final bool pricesIncludeTax;
  final String roundingMode;
  final String roundingIncrement;
  final String companyName;
  final String paymentMethods;
  final int version;
}

class CatalogPreferencesDto {
  const CatalogPreferencesDto({
    required this.cardsPerPage,
    required this.backgroundColor,
    required this.cardColor,
    required this.designAccentColor,
    required this.textColor,
    required this.highlightTextColor,
    required this.secondaryTextColor,
    required this.promotionColor,
    required this.promotionTextColor,
    required this.promotionPreviousPriceColor,
    required this.promotionPriceColor,
    required this.promotionDescriptionColor,
    required this.imageFit,
    required this.logoUrl,
    required this.selectedAgentId,
    required this.version,
  });

  final int cardsPerPage;
  final String backgroundColor;
  final String cardColor;
  final String designAccentColor;
  final String textColor;
  final String highlightTextColor;
  final String secondaryTextColor;
  final String promotionColor;
  final String promotionTextColor;
  final String promotionPreviousPriceColor;
  final String promotionPriceColor;
  final String promotionDescriptionColor;
  final String imageFit;
  final String? logoUrl;
  final String? selectedAgentId;
  final int version;
}

class PackagingPresentationDto {
  const PackagingPresentationDto({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.version,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;
  final int version;
}

class CatalogLogoReferenceDto {
  const CatalogLogoReferenceDto({
    required this.objectName,
    required this.version,
  });

  final String objectName;
  final int version;
}
