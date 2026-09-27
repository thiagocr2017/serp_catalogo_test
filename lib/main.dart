import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/configuration/app_configuration.dart';
import 'core/configuration/settings_providers.dart';
import 'core/configuration/settings_repository.dart';
import 'core/navigation/app_router.dart';
import 'core/device/device_identity.dart';
import 'modules/product/data/data_sources/supabase_product_data_source.dart';
import 'modules/product/data/repositories/supabase_product_repository.dart';
import 'modules/product/di/product_providers.dart';
import 'modules/product/services/product_image_service.dart';
import 'modules/product/data/repositories/supabase_promotion_repository.dart';
import 'modules/product/di/promotion_providers.dart';
import 'modules/inventory/data/data_sources/supabase_inventory_data_source.dart';
import 'modules/inventory/data/repositories/supabase_inventory_repository.dart';
import 'modules/inventory/di/inventory_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configuration = AppConfiguration.local();
  await Supabase.initialize(
    url: configuration.supabaseUrl,
    publishableKey: configuration.supabaseKey,
  );
  final device = await DeviceIdentity.detect();
  final repository = SupabaseProductRepository(
    SupabaseProductDataSource(Supabase.instance.client, device),
  );
  final inventoryRepository = SupabaseInventoryRepository(
    SupabaseInventoryDataSource(Supabase.instance.client),
    device,
  );
  final promotionRepository = SupabasePromotionRepository(
    Supabase.instance.client,
    device,
  );
  final settingsRepository = SettingsRepository(
    Supabase.instance.client,
    device,
  );
  final imageService = ProductImageService(Supabase.instance.client);

  runApp(
    ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(repository),
        inventoryRepositoryProvider.overrideWithValue(inventoryRepository),
        promotionRepositoryProvider.overrideWithValue(promotionRepository),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        productImageServiceProvider.overrideWithValue(imageService),
      ],
      child: const SerpApp(),
    ),
  );
}

class SerpApp extends ConsumerWidget {
  const SerpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SERP',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
    );
  }
}
