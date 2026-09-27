import 'package:supabase_flutter/supabase_flutter.dart';

import 'business_settings.dart';

class SettingsRepository {
  const SettingsRepository(this._client);
  final SupabaseClient _client;

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
        'updated_by': 'Desktop local',
        'updated_device_name': 'SERP Desktop',
        'updated_device_identifier': 'local-device',
      })
      .eq('id', true);
}
