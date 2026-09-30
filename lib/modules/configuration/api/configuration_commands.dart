import 'dart:typed_data';

import '../../../core/identity/identity_context.dart';
import 'configuration_dtos.dart';

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
    required this.preferences,
    required this.expectedVersion,
    required this.identity,
  });

  final CatalogPreferencesDto preferences;
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
