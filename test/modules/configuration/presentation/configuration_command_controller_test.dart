import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/identity/identity_context.dart';
import 'package:serp/modules/configuration/api/configuration_api.dart';
import 'package:serp/modules/configuration/presentation/controllers/configuration_command_controller.dart';

class _FakeConfigurationApi implements ConfigurationApi {
  SaveBusinessSettingsCommand? savedCommand;

  @override
  Future<bool> clearSelectedCatalogAgent(
    ClearSelectedCatalogAgentCommand command,
  ) async => true;

  @override
  Future<CatalogPreferences> getCatalogPreferences() async =>
      const CatalogPreferences();

  @override
  Future<List<PackagingPresentation>> getPackagingPresentations() async =>
      const [];

  @override
  Future<BusinessSettings> getBusinessSettings() async => _settings;

  @override
  Future<CatalogLogoReference> replaceCatalogLogo(
    ReplaceCatalogLogoCommand command,
  ) async => const CatalogLogoReference(objectName: 'catalog-logo', version: 1);

  @override
  Future<BusinessSettings> saveBusinessSettings(
    SaveBusinessSettingsCommand command,
  ) async {
    savedCommand = command;
    return _settings;
  }

  @override
  Future<CatalogPreferences> saveCatalogPreferences(
    SaveCatalogPreferencesCommand command,
  ) async => command.preferences;

  @override
  Future<PackagingPresentation> savePackagingPresentation(
    SavePackagingPresentationCommand command,
  ) async => const PackagingPresentation(
    id: 'presentation-1',
    name: 'Caja',
    sortOrder: 0,
  );

  @override
  Future<CatalogPreferences> selectCatalogAgent(
    SelectCatalogAgentCommand command,
  ) async => const CatalogPreferences();
}

const _settings = BusinessSettings(
  defaultCurrency: 'USD',
  decimalPlaces: 2,
  taxPercentage: 0,
  pricesIncludeTax: false,
  roundingMode: 'HALF_UP',
  roundingIncrement: 0.01,
  companyName: 'SERP',
  paymentMethods: '',
);

void main() {
  test('controller forwards an optimistic-version business command', () async {
    final api = _FakeConfigurationApi();
    final controller = ConfigurationCommandController(api);
    const command = SaveBusinessSettingsCommand(
      defaultCurrency: 'USD',
      decimalPlaces: 2,
      taxPercentage: 13,
      pricesIncludeTax: true,
      roundingMode: 'HALF_UP',
      roundingIncrement: 0.01,
      companyName: 'Empresa',
      paymentMethods: 'Transferencia',
      expectedVersion: 4,
      identity: IdentityContext(
        actorName: 'Equipo local',
        deviceName: 'Mac',
        deviceIdentifier: 'device-001',
      ),
    );

    await controller.saveBusinessSettings(command);

    expect(api.savedCommand, same(command));
    expect(api.savedCommand!.expectedVersion, 4);
  });
}
