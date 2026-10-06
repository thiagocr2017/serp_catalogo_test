import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/device/device_identity.dart';
import '../../domain/entities/business_settings.dart';
import '../../domain/entities/carrier.dart';
import '../../domain/entities/catalog_preferences.dart';
import '../../domain/entities/packaging_presentation.dart';
import '../../domain/repositories/configuration_repository.dart';

class SupabaseConfigurationRepository implements ConfigurationRepository {
  const SupabaseConfigurationRepository(this._client, this._device);
  final SupabaseClient _client;
  final DeviceIdentity _device;

  @override
  Future<BusinessSettings> get() async {
    final row = await _client.from('app_settings').select().single();
    return BusinessSettings(
      defaultCurrency: row['default_currency'] as String,
      decimalPlaces: row['decimal_places'] as int,
      taxPercentage: (row['tax_percentage'] as num).toDouble(),
      pricesIncludeTax: row['prices_include_tax'] as bool,
      roundingMode: row['rounding_mode'] as String,
      roundingIncrement: (row['rounding_increment'] as num).toDouble(),
      companyName: row['company_name'] as String,
      paymentMethods: row['payment_methods'] as String,
      appMode: row['app_mode'] as String? ?? 'TEST',
      isSuperAdmin: false,
    );
  }

  @override
  Future<void> save(BusinessSettings value) async {
    final row = await _client
        .from('app_settings')
        .select('business_settings_version')
        .eq('id', true)
        .single();
    final expectedVersion = row['business_settings_version'] as int;
    await _client.rpc<void>(
      'save_business_settings',
      params: {
        'p_default_currency': value.defaultCurrency,
        'p_decimal_places': value.decimalPlaces,
        'p_tax_percentage': value.taxPercentage,
        'p_prices_include_tax': value.pricesIncludeTax,
        'p_rounding_mode': value.roundingMode,
        'p_rounding_increment': value.roundingIncrement,
        'p_company_name': value.companyName,
        'p_payment_methods': value.paymentMethods,
        'p_expected_version': expectedVersion,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
  }

  @override
  Future<void> purgeTestDataAndGoProduction() => Future.error(
    UnsupportedError(
      'La transición a producción está bloqueada hasta implementar '
      'y verificar el bootstrap de Supabase Auth.',
    ),
  );

  @override
  Future<CatalogPreferences> getCatalogPreferences() async {
    final row = await _client.from('app_settings').select().single();
    return CatalogPreferences(
      cardsPerPage: row['catalog_cards_per_page'] as int? ?? 4,
      backgroundColor: row['catalog_background_color'] as String? ?? '#FFFFFF',
      cardColor: row['catalog_card_color'] as String? ?? '#FFFFFF',
      designAccentColor:
          row['catalog_design_accent_color'] as String? ?? '#3949AB',
      textColor: row['catalog_text_color'] as String? ?? '#111111',
      highlightTextColor:
          row['catalog_highlight_text_color'] as String? ?? '#1565C0',
      secondaryTextColor:
          row['catalog_secondary_text_color'] as String? ?? '#616161',
      promotionColor: row['catalog_promotion_color'] as String? ?? '#C62828',
      promotionTextColor:
          row['catalog_promotion_text_color'] as String? ?? '#FFFFFF',
      promotionPreviousPriceColor:
          row['catalog_promotion_previous_price_color'] as String? ?? '#757575',
      promotionPriceColor:
          row['catalog_promotion_price_color'] as String? ?? '#C62828',
      promotionDescriptionColor:
          row['catalog_promotion_description_color'] as String? ?? '#C62828',
      imageFit: row['catalog_image_fit'] as String? ?? 'cover',
      logoUrl: row['catalog_logo_object_name'] as String?,
      selectedAgentId: row['selected_catalog_agent_id'] as String?,
    );
  }

  @override
  Future<void> saveCatalogPreferences(CatalogPreferences value) async {
    final row = await _client
        .from('app_settings')
        .select('catalog_preferences_version')
        .eq('id', true)
        .single();
    final expectedVersion = row['catalog_preferences_version'] as int;
    await _client.rpc<void>(
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
        'p_promotion_previous_price_color': value.promotionPreviousPriceColor,
        'p_promotion_price_color': value.promotionPriceColor,
        'p_promotion_description_color': value.promotionDescriptionColor,
        'p_image_fit': value.imageFit,
        'p_expected_version': expectedVersion,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
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
  Future<List<PackagingPresentation>> getPackagingPresentations() async {
    final rows = await _client
        .from('packaging_presentations')
        .select()
        .eq('is_active', true)
        .order('sort_order')
        .order('name');
    return rows
        .map(
          (row) => PackagingPresentation(
            id: row['id'] as String,
            name: row['name'] as String,
            unitsPerPresentation: row['units_per_presentation'] as int? ?? 1,
            sortOrder: row['sort_order'] as int,
            isActive: row['is_active'] as bool,
          ),
        )
        .toList();
  }

  @override
  Future<PackagingPresentation> savePackagingPresentation({
    String? id,
    required String name,
    int unitsPerPresentation = 1,
  }) async {
    if (id == null) {
      final row = await _client.rpc<Map<String, dynamic>>(
        'create_packaging_presentation',
        params: {
          'p_command_id': _newUuid(),
          'p_name': name,
          'p_units_per_presentation': unitsPerPresentation,
          'p_actor_name': _device.actorName,
          'p_device_name': _device.name,
          'p_device_identifier': _device.identifier,
        },
      );
      return PackagingPresentation(
        id: row['id'] as String,
        name: row['name'] as String,
        unitsPerPresentation: unitsPerPresentation,
        sortOrder: row['sort_order'] as int,
        isActive: row['is_active'] as bool,
      );
    } else {
      final row = await _client
          .from('packaging_presentations')
          .select('version')
          .eq('id', id)
          .single();
      final expectedVersion = row['version'] as int;
      final result = await _client.rpc<Map<String, dynamic>>(
        'update_packaging_presentation',
        params: {
          'p_presentation_id': id,
          'p_name': name,
          'p_units_per_presentation': unitsPerPresentation,
          'p_expected_version': expectedVersion,
          'p_actor_name': _device.actorName,
          'p_device_name': _device.name,
          'p_device_identifier': _device.identifier,
        },
      );
      return PackagingPresentation(
        id: result['id'] as String,
        name: result['name'] as String,
        unitsPerPresentation: unitsPerPresentation,
        sortOrder: result['sort_order'] as int,
        isActive: result['is_active'] as bool,
      );
    }
  }

  @override
  Future<List<Carrier>> getCarriers() async {
    final rows = await _client
        .from('carriers')
        .select()
        .eq('is_active', true)
        .order('name');
    return rows.map(_carrier).toList();
  }

  @override
  Future<Carrier> saveCarrier({
    String? id,
    required String name,
    String? phone,
    String? address,
    String? contactName,
    String? notes,
  }) async {
    if (id == null) {
      final row = await _client.rpc<Map<String, dynamic>>(
        'create_carrier',
        params: {
          'p_command_id': _newUuid(),
          'p_name': name,
          'p_phone': phone,
          'p_address': address,
          'p_contact_name': contactName,
          'p_notes': notes,
          'p_actor_name': _device.actorName,
          'p_device_name': _device.name,
          'p_device_identifier': _device.identifier,
        },
      );
      return _carrier(row);
    }
    final row = await _client
        .from('carriers')
        .select('version')
        .eq('id', id)
        .single();
    final expectedVersion = row['version'] as int;
    final result = await _client.rpc<Map<String, dynamic>>(
      'update_carrier',
      params: {
        'p_carrier_id': id,
        'p_name': name,
        'p_phone': phone,
        'p_address': address,
        'p_contact_name': contactName,
        'p_notes': notes,
        'p_expected_version': expectedVersion,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _carrier(result);
  }

  Carrier _carrier(Map<String, dynamic> row) => Carrier(
    id: row['id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String?,
    address: row['address'] as String?,
    contactName: row['contact_name'] as String?,
    notes: row['notes'] as String?,
    isActive: row['is_active'] as bool? ?? true,
    version: row['version'] as int? ?? 1,
  );

  String _newUuid() {
    return const Uuid().v4();
  }
}
