import '../../api/configuration_api.dart';

/// Coordina comandos públicos; la pantalla se migrará a este controlador en
/// 1B.3, una vez que las RPC de 1B.2 estén disponibles.
class ConfigurationCommandController {
  const ConfigurationCommandController(this._api);

  final ConfigurationApi _api;

  Future<BusinessSettingsDto> saveBusinessSettings(
    SaveBusinessSettingsCommand command,
  ) => _api.saveBusinessSettings(command);

  Future<CatalogPreferencesDto> saveCatalogPreferences(
    SaveCatalogPreferencesCommand command,
  ) => _api.saveCatalogPreferences(command);

  Future<CatalogPreferencesDto> selectCatalogAgent(
    SelectCatalogAgentCommand command,
  ) => _api.selectCatalogAgent(command);

  Future<PackagingPresentationDto> createPackagingPresentation(
    CreatePackagingPresentationCommand command,
  ) => _api.createPackagingPresentation(command);

  Future<PackagingPresentationDto> updatePackagingPresentation(
    UpdatePackagingPresentationCommand command,
  ) => _api.updatePackagingPresentation(command);

  Future<PackagingPresentationDto> deactivatePackagingPresentation(
    DeactivatePackagingPresentationCommand command,
  ) => _api.deactivatePackagingPresentation(command);
}
