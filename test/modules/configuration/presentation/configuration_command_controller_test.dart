import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/identity/identity_context.dart';
import 'package:serp/modules/configuration/api/configuration_api.dart';
import 'package:serp/modules/configuration/presentation/controllers/configuration_command_controller.dart';

class _FakeConfigurationApi implements ConfigurationApi {
  SaveBusinessSettingsCommand? savedCommand;
  CreatePackagingPresentationCommand? createPresentationCommand;
  UpdatePackagingPresentationCommand? updatePresentationCommand;

  @override
  Future<CatalogPreferencesDto> getCatalogPreferences() async => _preferences;

  @override
  Future<List<PackagingPresentationDto>> getPackagingPresentations() async =>
      const [];

  @override
  Future<BusinessSettingsDto> getBusinessSettings() async => _settings;

  @override
  Future<CatalogLogoReferenceDto> replaceCatalogLogo(
    ReplaceCatalogLogoCommand command,
  ) async =>
      const CatalogLogoReferenceDto(objectName: 'catalog-logo', version: 1);

  @override
  Future<BusinessSettingsDto> saveBusinessSettings(
    SaveBusinessSettingsCommand command,
  ) async {
    savedCommand = command;
    return _settings;
  }

  @override
  Future<CatalogPreferencesDto> saveCatalogPreferences(
    SaveCatalogPreferencesCommand command,
  ) async => _preferences;

  @override
  Future<PackagingPresentationDto> createPackagingPresentation(
    CreatePackagingPresentationCommand command,
  ) async {
    createPresentationCommand = command;
    return const PackagingPresentationDto(
      id: 'presentation-1',
      name: 'Caja',
      sortOrder: 0,
      isActive: true,
      version: 3,
    );
  }

  @override
  Future<PackagingPresentationDto> updatePackagingPresentation(
    UpdatePackagingPresentationCommand command,
  ) async {
    updatePresentationCommand = command;
    return const PackagingPresentationDto(
      id: 'presentation-1',
      name: 'Caja actualizada',
      sortOrder: 0,
      isActive: true,
      version: 4,
    );
  }

  @override
  Future<CatalogPreferencesDto> selectCatalogAgent(
    SelectCatalogAgentCommand command,
  ) async => _preferences;
}

const _settings = BusinessSettingsDto(
  defaultCurrency: 'USD',
  decimalPlaces: 2,
  taxPercentage: '0.00',
  pricesIncludeTax: false,
  roundingMode: 'HALF_UP',
  roundingIncrement: '0.01',
  companyName: 'SERP',
  paymentMethods: '',
  version: 5,
);

const _preferences = CatalogPreferencesDto(
  cardsPerPage: 4,
  backgroundColor: '#FFFFFF',
  cardColor: '#FFFFFF',
  designAccentColor: '#3949AB',
  textColor: '#111111',
  highlightTextColor: '#1565C0',
  secondaryTextColor: '#616161',
  promotionColor: '#C62828',
  promotionTextColor: '#FFFFFF',
  promotionPreviousPriceColor: '#757575',
  promotionPriceColor: '#C62828',
  promotionDescriptionColor: '#C62828',
  imageFit: 'cover',
  logoObjectName: null,
  logoVersion: 2,
  selectedAgentId: null,
  version: 7,
);

void main() {
  test('controller forwards an optimistic-version business command', () async {
    final api = _FakeConfigurationApi();
    final controller = ConfigurationCommandController(api);
    final command = SaveBusinessSettingsCommand(
      defaultCurrency: 'USD',
      decimalPlaces: 2,
      taxPercentage: '13.00',
      pricesIncludeTax: true,
      roundingMode: 'HALF_UP',
      roundingIncrement: '0.01',
      companyName: 'Empresa',
      paymentMethods: 'Transferencia',
      expectedVersion: 4,
      identity: IdentityContext(
        actorName: 'Equipo local',
        deviceName: 'Mac',
        deviceIdentifier: 'device-001',
      ),
    );

    final updated = await controller.saveBusinessSettings(command);

    expect(api.savedCommand, same(command));
    expect(api.savedCommand!.expectedVersion, 4);
    expect(updated.version, 5);
    expect(command.taxPercentage, '13.00');
    expect(command.roundingIncrement, '0.01');
  });

  test(
    'presentation commands keep creation idempotency and edit version',
    () async {
      final api = _FakeConfigurationApi();
      final controller = ConfigurationCommandController(api);
      const identity = IdentityContext(
        actorName: 'Equipo local',
        deviceName: 'Mac',
        deviceIdentifier: 'device-001',
      );
      const create = CreatePackagingPresentationCommand(
        commandId: 'presentation-command-001',
        name: 'Caja',
        identity: identity,
      );
      const update = UpdatePackagingPresentationCommand(
        id: 'presentation-1',
        name: 'Caja actualizada',
        expectedVersion: 3,
        identity: identity,
      );

      final created = await controller.createPackagingPresentation(create);
      final updated = await controller.updatePackagingPresentation(update);

      expect(api.createPresentationCommand, same(create));
      expect(api.updatePresentationCommand, same(update));
      expect(created.version, 3);
      expect(updated.version, 4);
      expect(update.expectedVersion, 3);
    },
  );

  test('persistent decimal commands reject non-normalized values', () {
    const identity = IdentityContext(
      actorName: 'Equipo local',
      deviceName: 'Mac',
      deviceIdentifier: 'device-001',
    );

    expect(
      () => SaveBusinessSettingsCommand(
        defaultCurrency: 'USD',
        decimalPlaces: 2,
        taxPercentage: '13,00',
        pricesIncludeTax: true,
        roundingMode: 'HALF_UP',
        roundingIncrement: '0.01',
        companyName: 'Empresa',
        paymentMethods: '',
        expectedVersion: 1,
        identity: identity,
      ),
      throwsArgumentError,
    );
  });
}
