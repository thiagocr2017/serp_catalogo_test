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
    required this.logoObjectName,
    required this.logoVersion,
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

  /// Clave canónica del objeto de Storage; una URL es un detalle del adaptador.
  final String? logoObjectName;
  final int logoVersion;
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

class CarrierDto {
  const CarrierDto({
    required this.id,
    required this.name,
    required this.isActive,
    required this.version,
    this.phone,
    this.address,
    this.contactName,
    this.notes,
  });

  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? contactName;
  final String? notes;
  final bool isActive;
  final int version;
}

class IdentificationTypeDto {
  const IdentificationTypeDto({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
    required this.version,
  });

  final String id;
  final String code;
  final String name;
  final bool isActive;
  final int version;
}

class CountryDto {
  const CountryDto({
    required this.code,
    required this.name,
    this.isActive = true,
  });

  final String code;
  final String name;
  final bool isActive;
}

class AdministrativeAreaDto {
  const AdministrativeAreaDto({
    required this.id,
    required this.countryCode,
    required this.code,
    required this.name,
    this.isActive = true,
  });

  final String id;
  final String countryCode;
  final String code;
  final String name;
  final bool isActive;
}

class CityDto {
  const CityDto({
    required this.id,
    required this.countryCode,
    required this.provinceName,
    required this.name,
    this.isActive = true,
  });

  final String id;
  final String countryCode;
  final String provinceName;
  final String name;
  final bool isActive;
}
