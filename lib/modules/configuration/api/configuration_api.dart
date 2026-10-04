import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:typed_data';

import 'configuration_commands.dart';
import 'configuration_dtos.dart';

export 'configuration_commands.dart';
export 'configuration_dtos.dart';

/// Fachada pública de Configuración y su provider público.
/// Las implementaciones y providers de infraestructura son internos.
abstract interface class ConfigurationApi {
  Future<BusinessSettingsDto> getBusinessSettings();
  Future<CatalogPreferencesDto> getCatalogPreferences();
  Future<List<PackagingPresentationDto>> getPackagingPresentations();
  Future<List<CarrierDto>> getCarriers();

  /// Tipos de identificación. Los consumidores (formulario de cliente) solo
  /// necesitan los activos; la gestión en Configuración necesita todos.
  Future<List<IdentificationTypeDto>> getIdentificationTypes({
    bool includeInactive = false,
  });
  Future<IdentificationTypeDto> createIdentificationType(
    CreateIdentificationTypeCommand command,
  );
  Future<IdentificationTypeDto> updateIdentificationType(
    UpdateIdentificationTypeCommand command,
  );

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
  Future<PackagingPresentationDto> deactivatePackagingPresentation(
    DeactivatePackagingPresentationCommand command,
  );
  Future<CarrierDto> saveCarrier(SaveCarrierCommand command);
  Future<CatalogLogoReferenceDto> replaceCatalogLogo(
    ReplaceCatalogLogoCommand command,
  );

  Future<Uint8List?> downloadCatalogLogo();
}

final configurationApiProvider = Provider<ConfigurationApi>(
  (ref) => throw StateError('ConfigurationApi must be overridden.'),
);

final businessSettingsDtoProvider = FutureProvider<BusinessSettingsDto>(
  (ref) => ref.watch(configurationApiProvider).getBusinessSettings(),
);

final catalogPreferencesDtoProvider = FutureProvider<CatalogPreferencesDto>(
  (ref) => ref.watch(configurationApiProvider).getCatalogPreferences(),
);

final packagingPresentationDtosProvider =
    FutureProvider<List<PackagingPresentationDto>>(
      (ref) => ref.watch(configurationApiProvider).getPackagingPresentations(),
    );

final carrierDtosProvider = FutureProvider<List<CarrierDto>>(
  (ref) => ref.watch(configurationApiProvider).getCarriers(),
);

final identificationTypeDtosProvider = FutureProvider<List<IdentificationTypeDto>>(
  (ref) => ref.watch(configurationApiProvider).getIdentificationTypes(),
);

/// Incluye los inactivos: la gestión necesita reactivar tipos desactivados.
final identificationTypesAdminDtosProvider =
    FutureProvider<List<IdentificationTypeDto>>(
      (ref) =>
          ref.watch(configurationApiProvider).getIdentificationTypes(
            includeInactive: true,
          ),
    );
