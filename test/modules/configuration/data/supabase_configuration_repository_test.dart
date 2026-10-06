import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/device/device_identity.dart';
import 'package:serp/modules/configuration/data/repositories/supabase_configuration_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('production purge is locally rejected before any RPC call', () async {
    final repository = SupabaseConfigurationRepository(
      SupabaseClient('http://127.0.0.1:54321', 'test-key'),
      const DeviceIdentity(name: 'test-device', identifier: 'legacy-device'),
    );

    await expectLater(
      repository.purgeTestDataAndGoProduction(),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
