import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/identity/identity_context.dart';
import '../../api/configuration_api.dart';

class SupabaseConfigurationApi implements ConfigurationApi {
  const SupabaseConfigurationApi(this._client);

  final SupabaseClient _client;

  @override
  Future<BusinessSettingsDto> getBusinessSettings() async {
    final row = await _client
        .from('app_settings')
        .select()
        .eq('id', true)
        .single();
    return _business(row);
  }

  @override
  Future<CatalogPreferencesDto> getCatalogPreferences() async {
    final row = await _client
        .from('app_settings')
        .select()
        .eq('id', true)
        .single();
    return _catalog(row);
  }

  @override
  Future<List<PackagingPresentationDto>> getPackagingPresentations() async {
    final rows = await _client
        .from('packaging_presentations')
        .select()
        .eq('is_active', true)
        .order('sort_order')
        .order('name');
    return rows.map(_presentation).toList();
  }

  @override
  Future<List<CarrierDto>> getCarriers() async {
    final rows = await _client
        .from('carriers')
        .select()
        .eq('is_active', true)
        .order('name');
    return rows.map(_carrier).toList();
  }

  @override
  Future<List<IdentificationTypeDto>> getIdentificationTypes({
    bool includeInactive = false,
  }) async {
    final query = _client.from('identification_types').select();
    final rows = await (includeInactive
        ? query.order('name')
        : query.eq('is_active', true).order('name'));
    return rows.map(_identificationType).toList();
  }

  @override
  Future<List<CustomerCategoryDto>> getCustomerCategories({
    bool includeInactive = false,
  }) async {
    final query = _client.from('customer_categories').select();
    final rows = await (includeInactive
        ? query.order('name')
        : query.eq('is_active', true).order('name'));
    return rows
        .map((r) => _customerCategory(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<List<CountryDto>> getCountries() async {
    final response = await _client
        .from('countries')
        .select()
        .eq('is_active', true)
        .order('name');
    final rows = (response as List).map(
      (r) => Map<String, dynamic>.from(r as Map),
    );
    return rows.map(_country).toList();
  }

  @override
  Future<List<AdministrativeAreaDto>> getAdministrativeAreas({
    String countryCode = 'CR',
  }) async {
    final response = await _client
        .from('administrative_areas')
        .select()
        .eq('country_code', countryCode)
        .eq('is_active', true)
        .order('name');
    final rows = (response as List).map(
      (r) => Map<String, dynamic>.from(r as Map),
    );
    return rows.map(_administrativeArea).toList();
  }

  @override
  Future<List<CityDto>> getCities({
    String countryCode = 'CR',
    String? provinceName,
  }) async {
    var query = _client
        .from('cities')
        .select()
        .eq('country_code', countryCode)
        .eq('is_active', true);
    if (provinceName != null && provinceName.trim().isNotEmpty) {
      query = query.ilike('province_name', provinceName.trim());
    }
    final response = await query.order('name');
    final rows = (response as List).map(
      (r) => Map<String, dynamic>.from(r as Map),
    );
    return rows.map(_city).toList();
  }

  @override
  Future<IdentificationTypeDto> createIdentificationType(
    CreateIdentificationTypeCommand command,
  ) async {
    final row = await _client.rpc<dynamic>(
      'create_identification_type',
      params: {
        'p_command_id': command.commandId,
        'p_code': command.code,
        'p_name': command.name,
        ..._identity(command.identity),
      },
    );
    return _identificationType(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<IdentificationTypeDto> updateIdentificationType(
    UpdateIdentificationTypeCommand command,
  ) async {
    final row = await _client.rpc<dynamic>(
      'update_identification_type',
      params: {
        'p_type_id': command.id,
        'p_name': command.name,
        'p_is_active': command.isActive,
        'p_expected_version': command.expectedVersion,
        ..._identity(command.identity),
      },
    );
    return _identificationType(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<BusinessSettingsDto> saveBusinessSettings(
    SaveBusinessSettingsCommand command,
  ) async => _business(
    Map<String, dynamic>.from(
      await _client.rpc<dynamic>(
        'save_business_settings',
        params: {
          'p_default_currency': command.defaultCurrency,
          'p_decimal_places': command.decimalPlaces,
          'p_tax_percentage': command.taxPercentage,
          'p_prices_include_tax': command.pricesIncludeTax,
          'p_rounding_mode': command.roundingMode,
          'p_rounding_increment': command.roundingIncrement,
          'p_company_name': command.companyName,
          'p_payment_methods': command.paymentMethods,
          'p_expected_version': command.expectedVersion,
          ..._identity(command.identity),
        },
      ) as Map,
    ),
  );

  @override
  Future<CatalogPreferencesDto> saveCatalogPreferences(
    SaveCatalogPreferencesCommand command,
  ) async {
    final value = command.values;
    return _catalog(
      Map<String, dynamic>.from(
        await _client.rpc<dynamic>(
          'save_catalog_preferences',
          params: {
            'p_cards_per_page': value.cardsPerPage,
            'p_background_color': value.backgroundColor,
            'p_card_color': value.cardColor,
            'p_design_accent_color': value.designAccentColor,
            'p_text_color': value.textColor,
            'p_highlight_text_color': value.highlightTextColor,
            'p_secondary_text_color': value.secondaryTextColor,
            'p_promotion_color': value.promotionColor,
            'p_promotion_text_color': value.promotionTextColor,
            'p_promotion_previous_price_color':
                value.promotionPreviousPriceColor,
            'p_promotion_price_color': value.promotionPriceColor,
            'p_promotion_description_color': value.promotionDescriptionColor,
            'p_image_fit': value.imageFit,
            'p_expected_version': command.expectedVersion,
            ..._identity(command.identity),
          },
        ) as Map,
      ),
    );
  }

  @override
  Future<CatalogPreferencesDto> selectCatalogAgent(
    SelectCatalogAgentCommand command,
  ) async => _catalog(
    Map<String, dynamic>.from(
      await _client.rpc<dynamic>(
        'select_catalog_agent',
        params: {
          'p_agent_id': command.agentId,
          'p_expected_version': command.expectedVersion,
          ..._identity(command.identity),
        },
      ) as Map,
    ),
  );

  @override
  Future<PackagingPresentationDto> createPackagingPresentation(
    CreatePackagingPresentationCommand command,
  ) async => _presentation({
    ...Map<String, dynamic>.from(
      await _client.rpc<dynamic>(
        'create_packaging_presentation',
        params: {
          'p_command_id': command.commandId,
          'p_name': command.name,
          'p_units_per_presentation': command.unitsPerPresentation,
          ..._identity(command.identity),
        },
      ) as Map,
    ),
    'units_per_presentation': command.unitsPerPresentation,
  });

  @override
  Future<PackagingPresentationDto> updatePackagingPresentation(
    UpdatePackagingPresentationCommand command,
  ) async => _presentation({
    ...Map<String, dynamic>.from(
      await _client.rpc<dynamic>(
        'update_packaging_presentation',
        params: {
          'p_presentation_id': command.id,
          'p_name': command.name,
          'p_units_per_presentation': command.unitsPerPresentation,
          'p_expected_version': command.expectedVersion,
          ..._identity(command.identity),
        },
      ) as Map,
    ),
    'units_per_presentation': command.unitsPerPresentation,
  });

  @override
  Future<PackagingPresentationDto> deactivatePackagingPresentation(
    DeactivatePackagingPresentationCommand command,
  ) async => _presentation(
    Map<String, dynamic>.from(
      await _client.rpc<dynamic>(
        'deactivate_packaging_presentation',
        params: {
          'p_presentation_id': command.id,
          'p_expected_version': command.expectedVersion,
          ..._identity(command.identity),
        },
      ) as Map,
    ),
  );

  @override
  Future<CarrierDto> saveCarrier(SaveCarrierCommand command) async {
    if (command.id == null) {
      return _carrier(
        Map<String, dynamic>.from(
          await _client.rpc<dynamic>(
            'create_carrier',
            params: {
              'p_command_id': command.commandId,
              'p_name': command.name,
              'p_phone': command.phone,
              'p_address': command.address,
              'p_contact_name': command.contactName,
              'p_notes': command.notes,
              ..._identity(command.identity),
            },
          ) as Map,
        ),
      );
    }
    final expectedVersion = command.expectedVersion;
    if (expectedVersion == null) {
      throw ArgumentError.notNull('expectedVersion');
    }
    return _carrier(
      Map<String, dynamic>.from(
        await _client.rpc<dynamic>(
          'update_carrier',
          params: {
            'p_carrier_id': command.id,
            'p_name': command.name,
            'p_phone': command.phone,
            'p_address': command.address,
            'p_contact_name': command.contactName,
            'p_notes': command.notes,
            'p_expected_version': expectedVersion,
            ..._identity(command.identity),
          },
        ) as Map,
      ),
    );
  }

  @override
  Future<CatalogLogoReferenceDto> replaceCatalogLogo(
    ReplaceCatalogLogoCommand command,
  ) async {
    final objectName = 'catalog-logo/${command.operationId}';
    await _client.storage
        .from('catalog-assets')
        .uploadBinary(
          objectName,
          command.bytes,
          fileOptions: FileOptions(upsert: true, contentType: command.mimeType),
        );
    final row = Map<String, dynamic>.from(
      await _client.rpc<dynamic>(
        'register_catalog_logo_version',
        params: {
          'p_operation_id': command.operationId,
          'p_object_name': objectName,
          'p_mime_type': command.mimeType,
          'p_expected_logo_version': command.expectedVersion,
          ..._identity(command.identity),
        },
      ) as Map,
    );
    return CatalogLogoReferenceDto(
      objectName: row['object_name'] as String,
      version: row['version'] as int,
    );
  }

  @override
  Future<Uint8List?> downloadCatalogLogo() async {
    final row = await _client
        .from('app_settings')
        .select('catalog_logo_object_name')
        .eq('id', true)
        .single();
    final objectName = row['catalog_logo_object_name'] as String?;
    if (objectName == null || objectName.isEmpty) return null;
    return _client.storage.from('catalog-assets').download(objectName);
  }

  @override
  Future<CustomerCategoryDto> createCustomerCategory(
    CreateCustomerCategoryCommand command,
  ) async {
    final row = await _client.rpc<dynamic>(
      'create_customer_category',
      params: {
        'p_name': command.name,
        'p_description': command.description,
        'p_color': command.color,
      },
    );
    return _customerCategory(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<CustomerCategoryDto> updateCustomerCategory(
    UpdateCustomerCategoryCommand command,
  ) async {
    final row = await _client.rpc<dynamic>(
      'update_customer_category',
      params: {
        'p_id': command.id,
        'p_name': command.name,
        'p_description': command.description,
        'p_color': command.color,
        'p_is_active': command.isActive,
      },
    );
    return _customerCategory(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<void> deleteCustomerCategory(
    DeleteCustomerCategoryCommand command,
  ) async {
    await _client.rpc<dynamic>(
      'delete_customer_category',
      params: {'p_id': command.id},
    );
  }

  Map<String, dynamic> _identity(IdentityContext identity) => {
    'p_actor_name': identity.actorName,
    'p_device_name': identity.deviceName,
    'p_device_identifier': identity.deviceIdentifier,
  };

  BusinessSettingsDto _business(Map<String, dynamic> row) =>
      BusinessSettingsDto(
        defaultCurrency: row['default_currency'] as String,
        decimalPlaces: row['decimal_places'] as int,
        taxPercentage: row['tax_percentage'].toString(),
        pricesIncludeTax: row['prices_include_tax'] as bool,
        roundingMode: row['rounding_mode'] as String,
        roundingIncrement: row['rounding_increment'].toString(),
        companyName: row['company_name'] as String,
        paymentMethods: row['payment_methods'] as String,
        version:
            row['version'] as int? ?? row['business_settings_version'] as int,
      );

  CatalogPreferencesDto _catalog(
    Map<String, dynamic> row,
  ) => CatalogPreferencesDto(
    cardsPerPage:
        row['cards_per_page'] as int? ?? row['catalog_cards_per_page'] as int,
    backgroundColor:
        row['background_color'] as String? ??
        row['catalog_background_color'] as String,
    cardColor:
        row['card_color'] as String? ?? row['catalog_card_color'] as String,
    designAccentColor:
        row['design_accent_color'] as String? ??
        row['catalog_design_accent_color'] as String,
    textColor:
        row['text_color'] as String? ?? row['catalog_text_color'] as String,
    highlightTextColor:
        row['highlight_text_color'] as String? ??
        row['catalog_highlight_text_color'] as String,
    secondaryTextColor:
        row['secondary_text_color'] as String? ??
        row['catalog_secondary_text_color'] as String,
    promotionColor:
        row['promotion_color'] as String? ??
        row['catalog_promotion_color'] as String,
    promotionTextColor:
        row['promotion_text_color'] as String? ??
        row['catalog_promotion_text_color'] as String,
    promotionPreviousPriceColor:
        row['promotion_previous_price_color'] as String? ??
        row['catalog_promotion_previous_price_color'] as String,
    promotionPriceColor:
        row['promotion_price_color'] as String? ??
        row['catalog_promotion_price_color'] as String,
    promotionDescriptionColor:
        row['promotion_description_color'] as String? ??
        row['catalog_promotion_description_color'] as String,
    imageFit: row['image_fit'] as String? ?? row['catalog_image_fit'] as String,
    logoObjectName:
        row['logo_object_name'] as String? ??
        row['catalog_logo_object_name'] as String?,
    logoVersion:
        row['logo_version'] as int? ?? row['catalog_logo_version'] as int,
    selectedAgentId:
        row['selected_agent_id'] as String? ??
        row['selected_catalog_agent_id'] as String?,
    version:
        row['version'] as int? ?? row['catalog_preferences_version'] as int,
  );

  PackagingPresentationDto _presentation(Map<String, dynamic> row) =>
      PackagingPresentationDto(
        id: row['id'] as String,
        name: row['name'] as String,
        unitsPerPresentation: row['units_per_presentation'] as int? ?? 1,
        sortOrder: row['sort_order'] as int,
        isActive: row['is_active'] as bool,
        version: row['version'] as int,
      );

  CarrierDto _carrier(Map<String, dynamic> row) => CarrierDto(
    id: row['id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String?,
    address: row['address'] as String?,
    contactName: row['contact_name'] as String?,
    notes: row['notes'] as String?,
    isActive: row['is_active'] as bool? ?? true,
    version: row['version'] as int? ?? 1,
  );

  IdentificationTypeDto _identificationType(Map<String, dynamic> row) =>
      IdentificationTypeDto(
        id: row['id'] as String,
        code: row['code'] as String,
        name: row['name'] as String,
        isActive: row['is_active'] as bool? ?? true,
        version: row['version'] as int? ?? 1,
      );

  CountryDto _country(Map<String, dynamic> row) => CountryDto(
    code: row['code'] as String,
    name: row['name'] as String,
    isActive: row['is_active'] as bool? ?? true,
  );

  AdministrativeAreaDto _administrativeArea(Map<String, dynamic> row) =>
      AdministrativeAreaDto(
        id: row['id'] as String,
        countryCode: row['country_code'] as String,
        code: row['code'] as String,
        name: row['name'] as String,
        isActive: row['is_active'] as bool? ?? true,
      );

  CityDto _city(Map<String, dynamic> row) => CityDto(
    id: row['id'] as String,
    countryCode: row['country_code'] as String,
    provinceName: row['province_name'] as String,
    name: row['name'] as String,
    isActive: row['is_active'] as bool? ?? true,
  );

  CustomerCategoryDto _customerCategory(Map<String, dynamic> row) =>
      CustomerCategoryDto.fromJson(row);
}
