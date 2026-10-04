import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/business_settings.dart';
import '../domain/entities/carrier.dart';
import '../domain/entities/packaging_presentation.dart';
import '../domain/repositories/configuration_repository.dart';

final configurationRepositoryProvider = Provider<ConfigurationRepository>(
  (ref) => throw StateError('ConfigurationRepository must be overridden.'),
);
final businessSettingsProvider = FutureProvider<BusinessSettings>(
  (ref) => ref.watch(configurationRepositoryProvider).get(),
);
final packagingPresentationsProvider =
    FutureProvider<List<PackagingPresentation>>(
      (ref) => ref
          .watch(configurationRepositoryProvider)
          .getPackagingPresentations(),
    );

final carriersProvider = FutureProvider<List<Carrier>>(
  (ref) => ref.watch(configurationRepositoryProvider).getCarriers(),
);
