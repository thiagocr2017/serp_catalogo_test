import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_settings.dart';
import 'settings_repository.dart';
import 'packaging_presentation.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw StateError('SettingsRepository must be overridden.'),
);
final businessSettingsProvider = FutureProvider<BusinessSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).get(),
);
final packagingPresentationsProvider =
    FutureProvider<List<PackagingPresentation>>(
      (ref) =>
          ref.watch(settingsRepositoryProvider).getPackagingPresentations(),
    );
