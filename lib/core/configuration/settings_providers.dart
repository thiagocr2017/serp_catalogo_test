import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_settings.dart';
import 'settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw StateError('SettingsRepository must be overridden.'),
);
final businessSettingsProvider = FutureProvider<BusinessSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).get(),
);
