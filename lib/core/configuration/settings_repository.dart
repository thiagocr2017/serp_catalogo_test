import 'package:supabase_flutter/supabase_flutter.dart';

import '../device/device_identity.dart';
import 'business_settings.dart';

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
      packagingUnitLabel: row['packaging_unit_label'] as String? ?? 'Unidad',
      packagingBoxLabel: row['packaging_box_label'] as String? ?? 'Caja',
      packagingSetLabel: row['packaging_set_label'] as String? ?? 'Set',
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
        'packaging_unit_label': value.packagingUnitLabel,
        'packaging_box_label': value.packagingBoxLabel,
        'packaging_set_label': value.packagingSetLabel,
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
}
