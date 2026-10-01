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
  ) async => _presentation(
    Map<String, dynamic>.from(
      await _client.rpc<dynamic>(
        'create_packaging_presentation',
        params: {
          'p_command_id': command.commandId,
          'p_name': command.name,
          ..._identity(command.identity),
        },
      ) as Map,
    ),
  );

  @override
  Future<PackagingPresentationDto> updatePackagingPresentation(
    UpdatePackagingPresentationCommand command,
  ) async => _presentation(
    Map<String, dynamic>.from(
      await _client.rpc<dynamic>(
        'update_packaging_presentation',
        params: {
          'p_presentation_id': command.id,
          'p_name': command.name,
          'p_expected_version': command.expectedVersion,
          ..._identity(command.identity),
        },
      ) as Map,
    ),
  );

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
        sortOrder: row['sort_order'] as int,
        isActive: row['is_active'] as bool,
        version: row['version'] as int,
      );
}
