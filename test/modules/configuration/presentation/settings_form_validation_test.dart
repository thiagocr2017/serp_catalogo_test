import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/identity/identity_context.dart';
import 'package:serp/core/identity/identity_context_provider.dart';
import 'package:serp/modules/configuration/api/configuration_api.dart';
import 'package:serp/modules/configuration/di/configuration_providers.dart';
import 'package:serp/modules/configuration/domain/entities/business_settings.dart';
import 'package:serp/modules/configuration/domain/entities/carrier.dart';
import 'package:serp/modules/configuration/domain/entities/catalog_preferences.dart';
import 'package:serp/modules/configuration/domain/entities/packaging_presentation.dart';
import 'package:serp/modules/configuration/domain/repositories/configuration_repository.dart';
import 'package:serp/modules/configuration/presentation/pages/settings_page.dart';

void main() {
  testWidgets(
    'transicion a produccion queda bloqueada durante migracion Auth',
    (tester) async {
      final api = _RecordingConfigurationApi();

      await tester.pumpWidget(_app(api, isSuperAdmin: true));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Entorno de la aplicación'),
        500,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.textContaining('La transición a producción y la purga de datos'),
        findsOneWidget,
      );
      expect(
        find.text('Eliminar datos de prueba y pasar a producción'),
        findsNothing,
      );
    },
  );

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
    await tester.ensureVisible(find.text('Guardar configuración'));
    await tester.pumpAndSettle();
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
    await tester.enterText(
      find.widgetWithText(TextField, 'Unidades por presentación'),
      '6',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.createdPresentations, 1);
    expect(api.lastCreatedPresentationName, 'Cartón');
    expect(api.lastCreatedPresentationUnits, 6);
  });

  testWidgets('presentacion existente carga y actualiza por API publica', (
    tester,
  ) async {
    final api = _RecordingConfigurationApi(
      presentations: const [
        PackagingPresentationDto(
          id: 'presentation-1',
          name: 'Caja',
          unitsPerPresentation: 6,
          sortOrder: 0,
          isActive: true,
          version: 7,
        ),
      ],
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byTooltip('Editar presentación'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Editar presentación'));
    await tester.pumpAndSettle();

    expect(find.text('Editar presentación'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Caja'), findsOneWidget);
    expect(
      find.text('Debe ser único e indicar la cantidad incluida.'),
      findsOneWidget,
    );
    expect(
      find.text('Debe coincidir con la cantidad del nombre.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Unidades por presentación'),
          )
          .controller
          ?.text,
      '6',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Caja de 12 unidades',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Unidades por presentación'),
      '12',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.updatedPresentationId, 'presentation-1');
    expect(api.updatedPresentationName, 'Caja de 12 unidades');
    expect(api.updatedPresentationUnits, 12);
    expect(api.updatedPresentationVersion, 7);
  });

  testWidgets('presentacion existente se puede desactivar por API publica', (
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
      find.byTooltip('Desactivar presentación'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Desactivar presentación'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(api.deactivatedPresentationId, 'presentation-1');
    expect(api.deactivatedPresentationVersion, 7);
    expect(find.text('"Caja" fue desactivada.'), findsOneWidget);
  });

  testWidgets('transporte vacio exige correccion antes de guardar', (
    tester,
  ) async {
    final api = _RecordingConfigurationApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Nuevo transporte'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Nuevo transporte'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Escriba el nombre del transporte.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(api.savedCarriers, 0);

    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Ruta A');
    await tester.enterText(
      find.widgetWithText(TextField, 'Teléfono'),
      '+506 2222-1111',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.savedCarriers, 1);
    expect(api.lastCarrierCommand?.name, 'Ruta A');
    expect(api.lastCarrierCommand?.phone, '+506 2222-1111');
  });

  testWidgets(
    'tipo de identificacion vacio exige correccion antes de guardar',
    (tester) async {
      final api = _RecordingConfigurationApi();

      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Nuevo tipo'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Nuevo tipo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Escriba el código del tipo.'), findsOneWidget);
      expect(find.text('Escriba el nombre del tipo.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(api.createdIdentificationTypes, 0);

      await tester.enterText(find.widgetWithText(TextField, 'Código'), 'NIT');
      await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'NIT');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(api.createdIdentificationTypes, 1);
      expect(api.lastCreateIdentificationType?.code, 'NIT');
      expect(api.lastCreateIdentificationType?.name, 'NIT');
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('tipo de identificacion existente se renombra y desactiva', (
    tester,
  ) async {
    final api = _RecordingConfigurationApi(
      identificationTypes: const [
        IdentificationTypeDto(
          id: 'type-1',
          code: 'JURIDICAL_ID',
          name: 'Cédula jurídica',
          isActive: true,
          version: 3,
        ),
      ],
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Cédula jurídica'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Cédula jurídica'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Cédula jurídica (CR)',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.lastUpdateIdentificationType?.id, 'type-1');
    expect(api.lastUpdateIdentificationType?.name, 'Cédula jurídica (CR)');
    expect(api.lastUpdateIdentificationType?.isActive, false);
    expect(api.lastUpdateIdentificationType?.expectedVersion, 3);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('categoria comercial vacia exige nombre antes de guardar', (
    tester,
  ) async {
    final api = _RecordingConfigurationApi();

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Categorías comerciales de clientes'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Nueva categoría'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Escriba el nombre de la categoría.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre *'),
      'Mayorista',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Descripción'),
      'Ventas por mayor',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.lastCreateCustomerCategory?.name, 'Mayorista');
    expect(api.lastCreateCustomerCategory?.description, 'Ventas por mayor');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('categoria comercial existente edita y desactiva', (
    tester,
  ) async {
    final api = _RecordingConfigurationApi(
      customerCategories: const [
        CustomerCategoryDto(
          id: 'cat-1',
          name: 'Mayorista',
          description: 'Desc',
          isActive: true,
        ),
      ],
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Mayorista'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Mayorista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mayorista'));
    await tester.pumpAndSettle();

    expect(find.text('Editar categoría comercial'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Mayorista'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre *'),
      'Mayorista VIP',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(api.lastUpdateCustomerCategory?.id, 'cat-1');
    expect(api.lastUpdateCustomerCategory?.name, 'Mayorista VIP');
    expect(api.lastUpdateCustomerCategory?.isActive, false);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('categoria comercial existente se puede eliminar', (
    tester,
  ) async {
    final api = _RecordingConfigurationApi(
      customerCategories: const [
        CustomerCategoryDto(
          id: 'cat-1',
          name: 'Mayorista',
          description: 'Desc',
          isActive: true,
        ),
      ],
    );

    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Mayorista'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Mayorista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mayorista'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Eliminar categoría'));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar categoría comercial'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(api.lastDeleteCustomerCategory?.id, 'cat-1');
    expect(find.byType(AlertDialog), findsNothing);
  });
}

Widget _app(_RecordingConfigurationApi api, {bool isSuperAdmin = false}) =>
    ProviderScope(
      overrides: [
        configurationApiProvider.overrideWithValue(api),
        configurationRepositoryProvider.overrideWithValue(
          _LegacySettingsRepository(isSuperAdmin: isSuperAdmin),
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
  _RecordingConfigurationApi({
    this.presentations = const [],
    this.identificationTypes = const [],
    this.customerCategories = const [],
  });

  final List<PackagingPresentationDto> presentations;
  final List<IdentificationTypeDto> identificationTypes;
  int savedBusinessSettings = 0;
  int createdPresentations = 0;
  SaveBusinessSettingsCommand? lastBusinessCommand;
  String? lastCreatedPresentationName;
  int? lastCreatedPresentationUnits;
  String? updatedPresentationId;
  String? updatedPresentationName;
  int? updatedPresentationVersion;
  int? updatedPresentationUnits;
  String? deactivatedPresentationId;
  int? deactivatedPresentationVersion;
  int savedCarriers = 0;
  SaveCarrierCommand? lastCarrierCommand;
  int createdIdentificationTypes = 0;
  CreateIdentificationTypeCommand? lastCreateIdentificationType;
  UpdateIdentificationTypeCommand? lastUpdateIdentificationType;

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
  Future<List<CarrierDto>> getCarriers() async => const [];

  @override
  Future<List<IdentificationTypeDto>> getIdentificationTypes({
    bool includeInactive = false,
  }) async => identificationTypes;

  @override
  Future<IdentificationTypeDto> createIdentificationType(
    CreateIdentificationTypeCommand command,
  ) async {
    createdIdentificationTypes++;
    lastCreateIdentificationType = command;
    return IdentificationTypeDto(
      id: 'type-new',
      code: command.code,
      name: command.name,
      isActive: true,
      version: 1,
    );
  }

  @override
  Future<IdentificationTypeDto> updateIdentificationType(
    UpdateIdentificationTypeCommand command,
  ) async {
    lastUpdateIdentificationType = command;
    return IdentificationTypeDto(
      id: command.id,
      code: 'JURIDICAL_ID',
      name: command.name,
      isActive: command.isActive,
      version: command.expectedVersion + 1,
    );
  }

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
    lastCreatedPresentationUnits = command.unitsPerPresentation;
    return PackagingPresentationDto(
      id: command.commandId,
      name: command.name,
      unitsPerPresentation: command.unitsPerPresentation,
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
    updatedPresentationUnits = command.unitsPerPresentation;
    updatedPresentationVersion = command.expectedVersion;
    return PackagingPresentationDto(
      id: command.id,
      name: command.name,
      unitsPerPresentation: command.unitsPerPresentation,
      sortOrder: 0,
      isActive: true,
      version: command.expectedVersion + 1,
    );
  }

  @override
  Future<PackagingPresentationDto> deactivatePackagingPresentation(
    DeactivatePackagingPresentationCommand command,
  ) async {
    deactivatedPresentationId = command.id;
    deactivatedPresentationVersion = command.expectedVersion;
    final existing = presentations.firstWhere((item) => item.id == command.id);
    return PackagingPresentationDto(
      id: existing.id,
      name: existing.name,
      sortOrder: existing.sortOrder,
      isActive: false,
      version: command.expectedVersion + 1,
    );
  }

  @override
  Future<CarrierDto> saveCarrier(SaveCarrierCommand command) async {
    savedCarriers++;
    lastCarrierCommand = command;
    return CarrierDto(
      id: command.id ?? command.commandId,
      name: command.name,
      phone: command.phone,
      address: command.address,
      contactName: command.contactName,
      notes: command.notes,
      isActive: true,
      version: (command.expectedVersion ?? 0) + 1,
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

  @override
  Future<List<CountryDto>> getCountries() async => const [];

  @override
  Future<List<AdministrativeAreaDto>> getAdministrativeAreas({
    String countryCode = 'CR',
  }) async => const [];

  @override
  Future<List<CityDto>> getCities({
    String countryCode = 'CR',
    String? provinceName,
  }) async => const [];

  List<CustomerCategoryDto> customerCategories = const [];
  CreateCustomerCategoryCommand? lastCreateCustomerCategory;
  UpdateCustomerCategoryCommand? lastUpdateCustomerCategory;
  DeleteCustomerCategoryCommand? lastDeleteCustomerCategory;

  @override
  Future<List<CustomerCategoryDto>> getCustomerCategories({
    bool includeInactive = false,
  }) async => customerCategories;

  @override
  Future<CustomerCategoryDto> createCustomerCategory(
    CreateCustomerCategoryCommand command,
  ) async {
    lastCreateCustomerCategory = command;
    return CustomerCategoryDto(
      id: 'cat-new',
      name: command.name,
      description: command.description,
      color: command.color,
      isActive: true,
    );
  }

  @override
  Future<CustomerCategoryDto> updateCustomerCategory(
    UpdateCustomerCategoryCommand command,
  ) async {
    lastUpdateCustomerCategory = command;
    return CustomerCategoryDto(
      id: command.id,
      name: command.name,
      description: command.description,
      color: command.color,
      isActive: command.isActive,
    );
  }

  @override
  Future<void> deleteCustomerCategory(
    DeleteCustomerCategoryCommand command,
  ) async {
    lastDeleteCustomerCategory = command;
  }
}

class _LegacySettingsRepository implements ConfigurationRepository {
  _LegacySettingsRepository({this.isSuperAdmin = false});

  final bool isSuperAdmin;

  @override
  Future<BusinessSettings> get() async => BusinessSettings(
    defaultCurrency: 'USD',
    decimalPlaces: 2,
    taxPercentage: 0,
    pricesIncludeTax: false,
    roundingMode: 'HALF_UP',
    roundingIncrement: 0.01,
    companyName: '',
    paymentMethods: '',
    isSuperAdmin: isSuperAdmin,
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
  Future<List<Carrier>> getCarriers() async => const [];

  @override
  Future<PackagingPresentation> savePackagingPresentation({
    String? id,
    required String name,
    int unitsPerPresentation = 1,
  }) async => PackagingPresentation(
    id: id ?? 'presentation-new',
    name: name,
    unitsPerPresentation: unitsPerPresentation,
    sortOrder: 0,
  );

  @override
  Future<Carrier> saveCarrier({
    String? id,
    required String name,
    String? phone,
    String? address,
    String? contactName,
    String? notes,
  }) async => Carrier(
    id: id ?? 'carrier-new',
    name: name,
    phone: phone,
    address: address,
    contactName: contactName,
    notes: notes,
  );
}
