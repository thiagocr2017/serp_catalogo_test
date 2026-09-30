import 'dart:typed_data';

import '../../../core/identity/identity_context.dart';
import '../domain/entities/catalog_preferences.dart';

class SaveBusinessSettingsCommand {
  const SaveBusinessSettingsCommand({
    required this.defaultCurrency,
    required this.decimalPlaces,
    required this.taxPercentage,
    required this.pricesIncludeTax,
    required this.roundingMode,
    required this.roundingIncrement,
    required this.companyName,
    required this.paymentMethods,
    required this.expectedVersion,
    required this.identity,
  });

  final String defaultCurrency;
  final int decimalPlaces;
  final double taxPercentage;
  final bool pricesIncludeTax;
  final String roundingMode;
  final double roundingIncrement;
  final String companyName;
  final String paymentMethods;
  final int expectedVersion;
  final IdentityContext identity;
}

class SaveCatalogPreferencesCommand {
  const SaveCatalogPreferencesCommand({
    required this.preferences,
    required this.expectedVersion,
    required this.identity,
  });

  final CatalogPreferences preferences;
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

class ClearSelectedCatalogAgentCommand {
  const ClearSelectedCatalogAgentCommand({
    required this.agentId,
    required this.identity,
  });

  final String agentId;
  final IdentityContext identity;
}

class SavePackagingPresentationCommand {
  const SavePackagingPresentationCommand({
    this.id,
    required this.name,
    this.commandId,
    this.expectedVersion,
    required this.identity,
  });

  final String? id;
  final String name;
  final String? commandId;
  final int? expectedVersion;
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

class CatalogLogoReference {
  const CatalogLogoReference({required this.objectName, required this.version});

  final String objectName;
  final int version;
}
