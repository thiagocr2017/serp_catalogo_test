import 'dart:typed_data';

import '../../../core/identity/identity_context.dart';

class SaveBusinessSettingsCommand {
  SaveBusinessSettingsCommand({
    required this.defaultCurrency,
    required this.decimalPlaces,
    required String taxPercentage,
    required this.pricesIncludeTax,
    required this.roundingMode,
    required String roundingIncrement,
    required this.companyName,
    required this.paymentMethods,
    required this.expectedVersion,
    required this.identity,
  }) : taxPercentage = _validatedDecimal(taxPercentage, field: 'taxPercentage'),
       roundingIncrement = _validatedDecimal(
         roundingIncrement,
         field: 'roundingIncrement',
       );

  final String defaultCurrency;
  final int decimalPlaces;

  /// Decimal normalizado, por ejemplo `13.00`.
  final String taxPercentage;
  final bool pricesIncludeTax;
  final String roundingMode;

  /// Decimal normalizado, por ejemplo `0.01`.
  final String roundingIncrement;
  final String companyName;
  final String paymentMethods;
  final int expectedVersion;
  final IdentityContext identity;
}

String _validatedDecimal(String value, {required String field}) {
  if (!RegExp(r'^(0|[1-9]\d*)(\.\d+)?$').hasMatch(value)) {
    throw ArgumentError.value(
      value,
      field,
      'Debe ser un decimal normalizado sin separador de miles.',
    );
  }
  return value;
}

class SaveCatalogPreferencesCommand {
  const SaveCatalogPreferencesCommand({
    required this.values,
    required this.expectedVersion,
    required this.identity,
  });

  final CatalogDesignPreferencesInput values;
  final int expectedVersion;
  final IdentityContext identity;
}

class SelectCatalogAgentCommand {
  const SelectCatalogAgentCommand({
    required this.agentId,
    required this.expectedVersion,
    required this.identity,
  });

  final String? agentId;
  final int expectedVersion;
  final IdentityContext identity;
}

class CreatePackagingPresentationCommand {
  const CreatePackagingPresentationCommand({
    required this.commandId,
    required this.name,
    required this.identity,
  });

  final String commandId;
  final String name;
  final IdentityContext identity;
}

class UpdatePackagingPresentationCommand {
  const UpdatePackagingPresentationCommand({
    required this.id,
    required this.name,
    required this.expectedVersion,
    required this.identity,
  });

  final String id;
  final String name;
  final int expectedVersion;
  final IdentityContext identity;
}

class DeactivatePackagingPresentationCommand {
  const DeactivatePackagingPresentationCommand({
    required this.id,
    required this.expectedVersion,
    required this.identity,
  });

  final String id;
  final int expectedVersion;
  final IdentityContext identity;
}

class SaveCarrierCommand {
  const SaveCarrierCommand({
    this.id,
    required this.commandId,
    required this.name,
    this.phone,
    this.address,
    this.contactName,
    this.notes,
    this.expectedVersion,
    required this.identity,
  });

  final String? id;
  final String commandId;
  final String name;
  final String? phone;
  final String? address;
  final String? contactName;
  final String? notes;
  final int? expectedVersion;
  final IdentityContext identity;
}

class CreateIdentificationTypeCommand {
  const CreateIdentificationTypeCommand({
    required this.commandId,
    required this.code,
    required this.name,
    required this.identity,
  });

  final String commandId;
  final String code;
  final String name;
  final IdentityContext identity;
}

class UpdateIdentificationTypeCommand {
  const UpdateIdentificationTypeCommand({
    required this.id,
    required this.name,
    required this.isActive,
    required this.expectedVersion,
    required this.identity,
  });

  final String id;
  final String name;
  final bool isActive;
  final int expectedVersion;
  final IdentityContext identity;
}

class ReplaceCatalogLogoCommand {
  const ReplaceCatalogLogoCommand({
    required this.operationId,
    required this.bytes,
    required this.mimeType,
    required this.expectedVersion,
    required this.identity,
  });

  final String operationId;
  final Uint8List bytes;
  final String mimeType;
  final int expectedVersion;
  final IdentityContext identity;
}

/// Valores de diseño que una pantalla puede actualizar en bloque.
/// No contiene logo, agente seleccionado ni metadatos de concurrencia.
class CatalogDesignPreferencesInput {
  const CatalogDesignPreferencesInput({
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
}

class CreateCustomerCategoryCommand {
  const CreateCustomerCategoryCommand({
    required this.name,
    this.description,
    this.color,
    this.identity,
  });

  final String name;
  final String? description;
  final String? color;
  final IdentityContext? identity;
}

class UpdateCustomerCategoryCommand {
  const UpdateCustomerCategoryCommand({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.isActive = true,
    this.identity,
  });

  final String id;
  final String name;
  final String? description;
  final String? color;
  final bool isActive;
  final IdentityContext? identity;
}

class DeleteCustomerCategoryCommand {
  const DeleteCustomerCategoryCommand({
    required this.id,
    this.identity,
  });

  final String id;
  final IdentityContext? identity;
}
