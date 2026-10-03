import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/identity/identity_context.dart';
import 'package:serp/core/identity/identity_context_provider.dart';
import 'package:serp/modules/configuration/api/configuration_api.dart';
import 'package:serp/modules/configuration/di/configuration_providers.dart';
import 'package:serp/modules/configuration/domain/entities/business_settings.dart';
import 'package:serp/modules/configuration/domain/entities/catalog_preferences.dart';
import 'package:serp/modules/configuration/domain/entities/packaging_presentation.dart';
import 'package:serp/modules/configuration/domain/repositories/configuration_repository.dart';
import 'package:serp/modules/configuration/presentation/pages/settings_page.dart';

void main() {
  testWidgets('configuracion guarda datos validos usando la API publica', (
    tester,
  ) async {
    final api = _RecordingConfigurationApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre de empresa'),
      'Mi Empresa',
    );
    await tester.scrollUntilVisible(
      find.text('Guardar configuración'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();

    expect(api.savedBusinessSettings, 1);
    expect(api.lastBusinessCommand?.companyName, 'Mi Empresa');
  });

  testWidgets('configuracion rechaza decimales con formato invalido', (
    tester,
  ) async {
    final api = _RecordingConfigurationApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Impuesto %'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.widgetWithText(TextField, 'Impuesto %'), '1,5');
    await tester.scrollUntilVisible(
      find.text('Guardar configuración'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();

    expect(api.savedBusinessSettings, 0);
    expect(find.textContaining('No fue posible guardar'), findsOneWidget);
  });

  testWidgets('presentacion vacia exige correccion antes de guardar', (
    tester,
  ) async {
    final api = _RecordingConfigurationApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Nueva presentación'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Nueva presentación'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Escriba el nombre de la presentación.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(api.createdPresentations, 0);

    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Cartón');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdPresentations, 1);
    expect(api.lastCreatedPresentationName, 'Cartón');
  });

  testWidgets('presentacion existente carga y actualiza por API publica', (
    tester,
  ) async {
    final api = _RecordingConfigurationApi(
      presentations: const [
        PackagingPresentationDto(
          id: 'presentation-1',
          name: 'Caja',
          sortOrder: 0,
          isActive: true,
          version: 7,
        ),
      ],
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Caja'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Caja'));
    await tester.pumpAndSettle();

    expect(find.text('Editar presentación'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Caja'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Cartón');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.updatedPresentationId, 'presentation-1');
    expect(api.updatedPresentationName, 'Cartón');
    expect(api.updatedPresentationVersion, 7);
  });
}

Widget _app(_RecordingConfigurationApi api) => ProviderScope(
  overrides: [
    configurationApiProvider.overrideWithValue(api),
    configurationRepositoryProvider.overrideWithValue(
      _LegacySettingsRepository(),
    ),
    identityContextProvider.overrideWithValue(
      const IdentityContext(
        actorName: 'test',
        deviceName: 'device',
        deviceIdentifier: 'device-1',
      ),
    ),
  ],
  child: const MaterialApp(home: SettingsPage()),
);

class _RecordingConfigurationApi implements ConfigurationApi {
  _RecordingConfigurationApi({this.presentations = const []});

  final List<PackagingPresentationDto> presentations;
  int savedBusinessSettings = 0;
  int createdPresentations = 0;
  SaveBusinessSettingsCommand? lastBusinessCommand;
  String? lastCreatedPresentationName;
  String? updatedPresentationId;
  String? updatedPresentationName;
  int? updatedPresentationVersion;

  @override
  Future<BusinessSettingsDto> getBusinessSettings() async =>
      const BusinessSettingsDto(
        defaultCurrency: 'USD',
        decimalPlaces: 2,
        taxPercentage: '0',
        pricesIncludeTax: false,
        roundingMode: 'HALF_UP',
        roundingIncrement: '0.01',
        companyName: '',
        paymentMethods: '',
        version: 1,
      );

  @override
  Future<CatalogPreferencesDto> getCatalogPreferences() async =>
      const CatalogPreferencesDto(
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
        logoVersion: 1,
        selectedAgentId: null,
        version: 1,
      );

  @override
  Future<List<PackagingPresentationDto>> getPackagingPresentations() async =>
      presentations;

  @override
  Future<BusinessSettingsDto> saveBusinessSettings(
    SaveBusinessSettingsCommand command,
  ) async {
    savedBusinessSettings++;
    lastBusinessCommand = command;
    return BusinessSettingsDto(
      defaultCurrency: command.defaultCurrency,
      decimalPlaces: command.decimalPlaces,
      taxPercentage: command.taxPercentage,
      pricesIncludeTax: command.pricesIncludeTax,
      roundingMode: command.roundingMode,
      roundingIncrement: command.roundingIncrement,
      companyName: command.companyName,
      paymentMethods: command.paymentMethods,
      version: command.expectedVersion + 1,
    );
  }

  @override
  Future<CatalogPreferencesDto> saveCatalogPreferences(
    SaveCatalogPreferencesCommand command,
  ) async => getCatalogPreferences();

  @override
  Future<CatalogPreferencesDto> selectCatalogAgent(
    SelectCatalogAgentCommand command,
  ) async => getCatalogPreferences();

  @override
  Future<PackagingPresentationDto> createPackagingPresentation(
    CreatePackagingPresentationCommand command,
  ) async {
    createdPresentations++;
    lastCreatedPresentationName = command.name;
    return PackagingPresentationDto(
      id: command.commandId,
      name: command.name,
      sortOrder: 0,
      isActive: true,
      version: 1,
    );
  }

  @override
  Future<PackagingPresentationDto> updatePackagingPresentation(
    UpdatePackagingPresentationCommand command,
  ) async {
    updatedPresentationId = command.id;
    updatedPresentationName = command.name;
    updatedPresentationVersion = command.expectedVersion;
    return PackagingPresentationDto(
      id: command.id,
      name: command.name,
      sortOrder: 0,
      isActive: true,
      version: command.expectedVersion + 1,
    );
  }

  @override
  Future<CatalogLogoReferenceDto> replaceCatalogLogo(
    ReplaceCatalogLogoCommand command,
  ) async => CatalogLogoReferenceDto(
    objectName: 'catalog-logo/${command.operationId}',
    version: command.expectedVersion + 1,
  );

  @override
  Future<Uint8List?> downloadCatalogLogo() async => null;
}

class _LegacySettingsRepository implements ConfigurationRepository {
  @override
  Future<BusinessSettings> get() async => const BusinessSettings(
    defaultCurrency: 'USD',
    decimalPlaces: 2,
    taxPercentage: 0,
    pricesIncludeTax: false,
    roundingMode: 'HALF_UP',
    roundingIncrement: 0.01,
    companyName: '',
    paymentMethods: '',
  );

  @override
  Future<void> save(BusinessSettings value) async {}

  @override
  Future<void> purgeTestDataAndGoProduction() async {}

  @override
  Future<CatalogPreferences> getCatalogPreferences() async =>
      const CatalogPreferences();

  @override
  Future<void> saveCatalogPreferences(CatalogPreferences value) async {}

  @override
  Future<Uint8List?> downloadCatalogLogo() async => null;

  @override
  Future<List<PackagingPresentation>> getPackagingPresentations() async =>
      const [];

  @override
  Future<PackagingPresentation> savePackagingPresentation({
    String? id,
    required String name,
  }) async => PackagingPresentation(
    id: id ?? 'presentation-new',
    name: name,
    sortOrder: 0,
  );
}
