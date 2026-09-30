import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'configuration_commands.dart';
import '../domain/entities/business_settings.dart';
import '../domain/entities/catalog_preferences.dart';
import '../domain/entities/packaging_presentation.dart';

export '../domain/entities/business_settings.dart';
export '../domain/entities/catalog_preferences.dart';
export '../domain/entities/packaging_presentation.dart';
export 'configuration_commands.dart';

// Puente temporal para consumidores heredados. Se eliminará en 1B.3 después
// de migrarlos a ConfigurationApi; ningún código nuevo debe usar estos exports.
export '../di/configuration_providers.dart'
    show
        businessSettingsProvider,
        configurationRepositoryProvider,
        packagingPresentationsProvider;

/// Fachada pública de Configuración.
///
/// La implementación y los providers de infraestructura siguen transitoriamente
/// internos hasta que los consumidores se migren en 1B.3.
abstract interface class ConfigurationApi {
  Future<BusinessSettings> getBusinessSettings();
  Future<CatalogPreferences> getCatalogPreferences();
  Future<List<PackagingPresentation>> getPackagingPresentations();

  Future<BusinessSettings> saveBusinessSettings(
    SaveBusinessSettingsCommand command,
  );
  Future<CatalogPreferences> saveCatalogPreferences(
    SaveCatalogPreferencesCommand command,
  );
  Future<CatalogPreferences> selectCatalogAgent(
    SelectCatalogAgentCommand command,
  );
  Future<bool> clearSelectedCatalogAgent(
    ClearSelectedCatalogAgentCommand command,
  );
  Future<PackagingPresentation> savePackagingPresentation(
    SavePackagingPresentationCommand command,
  );
  Future<CatalogLogoReference> replaceCatalogLogo(
    ReplaceCatalogLogoCommand command,
  );
}

final configurationApiProvider = Provider<ConfigurationApi>(
  (ref) => throw StateError('ConfigurationApi must be overridden.'),
);
