import '../../api/configuration_api.dart';

/// Coordina comandos públicos; la pantalla se migrará a este controlador en
/// 1B.3, una vez que las RPC de 1B.2 estén disponibles.
class ConfigurationCommandController {
  const ConfigurationCommandController(this._api);

  final ConfigurationApi _api;

  Future<void> saveBusinessSettings(SaveBusinessSettingsCommand command) async {
    await _api.saveBusinessSettings(command);
  }

  Future<void> saveCatalogPreferences(
    SaveCatalogPreferencesCommand command,
  ) async {
    await _api.saveCatalogPreferences(command);
  }

  Future<void> selectCatalogAgent(SelectCatalogAgentCommand command) async {
    await _api.selectCatalogAgent(command);
  }

  Future<bool> clearSelectedCatalogAgent(
    ClearSelectedCatalogAgentCommand command,
  ) => _api.clearSelectedCatalogAgent(command);
}
