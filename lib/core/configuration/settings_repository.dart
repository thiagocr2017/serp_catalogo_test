import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../device/device_identity.dart';
import 'business_settings.dart';
import 'catalog_preferences.dart';
import 'packaging_presentation.dart';

class SettingsRepository {
  const SettingsRepository(this._client, this._device);
  final SupabaseClient _client;
  final DeviceIdentity _device;

  Future<BusinessSettings> get() async {
    var row = await _client.from('app_settings').select().single();
    if (row['superadmin_device_identifier'] == null) {
      await _client
          .from('app_settings')
          .update({'superadmin_device_identifier': _device.identifier})
          .eq('id', true)
          .isFilter('superadmin_device_identifier', null);
      row = await _client.from('app_settings').select().single();
    }
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
      isSuperAdmin: row['superadmin_device_identifier'] == _device.identifier,
    );
  }

  Future<void> save(BusinessSettings value) => _client
      .from('app_settings')
      .update({
        'default_currency': value.defaultCurrency,
        'decimal_places': value.decimalPlaces,
        'tax_percentage': value.taxPercentage,
        'prices_include_tax': value.pricesIncludeTax,
        'rounding_mode': value.roundingMode,
        'rounding_increment': value.roundingIncrement,
        'company_name': value.companyName,
        'payment_methods': value.paymentMethods,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': _device.actorName,
        'updated_device_name': _device.name,
        'updated_device_identifier': _device.identifier,
      })
      .eq('id', true);

  Future<void> purgeTestDataAndGoProduction() => _client.rpc<void>(
    'purge_test_data_and_go_production',
    params: {
      'p_actor_name': _device.actorName,
      'p_device_identifier': _device.identifier,
    },
  );

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
      logoUrl: row['catalog_logo_url'] as String?,
      selectedAgentId: row['selected_catalog_agent_id'] as String?,
    );
  }

  Future<void> saveCatalogPreferences(CatalogPreferences value) async {
    await _client
        .from('app_settings')
        .update({
          'catalog_cards_per_page': value.cardsPerPage,
          'catalog_background_color': value.backgroundColor,
          'catalog_card_color': value.cardColor,
          'catalog_design_accent_color': value.designAccentColor,
          'catalog_text_color': value.textColor,
          'catalog_highlight_text_color': value.highlightTextColor,
          'catalog_secondary_text_color': value.secondaryTextColor,
          'catalog_promotion_color': value.promotionColor,
          'catalog_promotion_text_color': value.promotionTextColor,
          'catalog_promotion_previous_price_color':
              value.promotionPreviousPriceColor,
          'catalog_promotion_price_color': value.promotionPriceColor,
          'catalog_promotion_description_color':
              value.promotionDescriptionColor,
          'catalog_image_fit': value.imageFit,
          'catalog_logo_url': value.logoUrl,
          'selected_catalog_agent_id': value.selectedAgentId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'updated_by': _device.actorName,
          'updated_device_name': _device.name,
          'updated_device_identifier': _device.identifier,
        })
        .eq('id', true)
        .select('catalog_cards_per_page')
        .single();
  }

  Future<void> setCatalogLogoUrl(String url) => _client
      .from('app_settings')
      .update({
        'catalog_logo_url': url,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': _device.actorName,
        'updated_device_name': _device.name,
        'updated_device_identifier': _device.identifier,
      })
      .eq('id', true);

  Future<String> uploadCatalogLogo(Uint8List bytes, String extension) async {
    final safeExtension = extension.toLowerCase() == 'png' ? 'png' : 'jpg';
    final path = 'catalog-logo.$safeExtension';
    await _client.storage
        .from('catalog-assets')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: safeExtension == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
    final url = _client.storage.from('catalog-assets').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<Uint8List?> downloadCatalogLogo(String? url) async {
    if (url == null || url.isEmpty) return null;
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      return Uint8List.fromList(bytes);
    } finally {
      client.close(force: true);
    }
  }

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
            sortOrder: row['sort_order'] as int,
            isActive: row['is_active'] as bool,
          ),
        )
        .toList();
  }

  Future<PackagingPresentation> savePackagingPresentation({
    String? id,
    required String name,
  }) async {
    final values = {
      'name': name.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': _device.actorName,
      'updated_device_name': _device.name,
      'updated_device_identifier': _device.identifier,
    };
    final Map<String, dynamic> row;
    if (id == null) {
      final existing = await getPackagingPresentations();
      row = await _client
          .from('packaging_presentations')
          .insert({
            ...values,
            'sort_order': existing.length,
            'created_by': _device.actorName,
            'created_device_name': _device.name,
            'created_device_identifier': _device.identifier,
          })
          .select()
          .single();
    } else {
      row = await _client
          .from('packaging_presentations')
          .update(values)
          .eq('id', id)
          .select()
          .single();
    }
    return PackagingPresentation(
      id: row['id'] as String,
      name: row['name'] as String,
      sortOrder: row['sort_order'] as int,
      isActive: row['is_active'] as bool,
    );
  }
}
