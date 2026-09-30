import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'configuration_commands.dart';
import 'configuration_dtos.dart';

export 'configuration_commands.dart';
export 'configuration_dtos.dart';

// Puente temporal de tipos para consumidores heredados; se elimina en 1B.3.
// Ningún contrato nuevo depende de estas entidades internas.
export '../domain/entities/business_settings.dart';
export '../domain/entities/catalog_preferences.dart';
export '../domain/entities/packaging_presentation.dart';

/// Fachada pública de Configuración y su provider público.
/// Las implementaciones y providers de infraestructura son internos.
abstract interface class ConfigurationApi {
  Future<BusinessSettingsDto> getBusinessSettings();
  Future<CatalogPreferencesDto> getCatalogPreferences();
  Future<List<PackagingPresentationDto>> getPackagingPresentations();

  Future<BusinessSettingsDto> saveBusinessSettings(
    SaveBusinessSettingsCommand command,
  );
  Future<CatalogPreferencesDto> saveCatalogPreferences(
    SaveCatalogPreferencesCommand command,
  );
  Future<CatalogPreferencesDto> selectCatalogAgent(
    SelectCatalogAgentCommand command,
  );
  Future<PackagingPresentationDto> createPackagingPresentation(
    CreatePackagingPresentationCommand command,
  );
  Future<PackagingPresentationDto> updatePackagingPresentation(
    UpdatePackagingPresentationCommand command,
  );
  Future<CatalogLogoReferenceDto> replaceCatalogLogo(
    ReplaceCatalogLogoCommand command,
  );
}

final configurationApiProvider = Provider<ConfigurationApi>(
  (ref) => throw StateError('ConfigurationApi must be overridden.'),
);
