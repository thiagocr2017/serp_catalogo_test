import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/configuration/app_configuration.dart';
import 'core/configuration/theme_mode_controller.dart';
import 'core/navigation/app_router.dart';
import 'core/device/device_identity.dart';
import 'core/identity/identity_context.dart';
import 'core/identity/identity_context_provider.dart';
import 'modules/configuration/data/repositories/supabase_configuration_repository.dart';
import 'modules/configuration/data/repositories/supabase_configuration_api.dart';
import 'modules/configuration/configuration_module.dart';
import 'modules/configuration/di/configuration_providers.dart';
import 'modules/product/data/data_sources/supabase_product_data_source.dart';
import 'modules/product/data/repositories/supabase_product_repository.dart';
import 'modules/product/di/product_providers.dart';
import 'modules/product/product_module.dart';
import 'modules/product/services/product_image_service.dart';
import 'modules/product/data/repositories/supabase_promotion_repository.dart';
import 'modules/product/di/promotion_providers.dart';
import 'modules/inventory/data/data_sources/supabase_inventory_data_source.dart';
import 'modules/inventory/data/repositories/supabase_inventory_repository.dart';
import 'modules/inventory/di/inventory_providers.dart';
import 'modules/inventory/inventory_module.dart';
import 'modules/sales/data/data_sources/supabase_sales_data_source.dart';
import 'modules/sales/data/repositories/supabase_sales_repository.dart';
import 'modules/sales/di/sales_providers.dart';
import 'modules/sales/sales_module.dart';
import 'modules/payments/data/data_sources/supabase_payment_data_source.dart';
import 'modules/payments/data/repositories/supabase_payment_repository.dart';
import 'modules/payments/data/repositories/supabase_payment_api.dart';
import 'modules/payments/di/payment_providers.dart';
import 'modules/payments/payments_module.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/app_loading_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AppBootstrap()));
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<Widget> _appFuture;

  @override
  void initState() {
    super.initState();
    _appFuture = _initializeApp();
  }

  Future<Widget> _initializeApp() async {
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
    final configurationRepository = SupabaseConfigurationRepository(
      Supabase.instance.client,
      device,
    );
    final configurationApi = SupabaseConfigurationApi(Supabase.instance.client);
    final imageService = ProductImageService(Supabase.instance.client);
    final salesRepository = SupabaseSalesRepository(
      SupabaseSalesDataSource(Supabase.instance.client),
    );
    final paymentDataSource = SupabasePaymentDataSource(
      Supabase.instance.client,
      device,
    );
    final paymentRepository = SupabasePaymentRepository(paymentDataSource);
    final paymentApi = SupabasePaymentApi(paymentDataSource);

    return ProviderScope(
      overrides: [
        identityContextProvider.overrideWithValue(
          IdentityContext(
            actorName: device.actorName,
            deviceName: device.name,
            deviceIdentifier: device.identifier,
          ),
        ),
        productRepositoryProvider.overrideWithValue(repository),
        productApiProvider.overrideWithValue(repository),
        inventoryRepositoryProvider.overrideWithValue(inventoryRepository),
        inventoryApiProvider.overrideWithValue(inventoryRepository),
        promotionRepositoryProvider.overrideWithValue(promotionRepository),
        configurationRepositoryProvider.overrideWithValue(
          configurationRepository,
        ),
        configurationApiProvider.overrideWithValue(configurationApi),
        productImageServiceProvider.overrideWithValue(imageService),
        salesRepositoryProvider.overrideWithValue(salesRepository),
        salesApiProvider.overrideWithValue(salesRepository),
        paymentRepositoryProvider.overrideWithValue(paymentRepository),
        paymentApiProvider.overrideWithValue(paymentApi),
      ],
      child: const SerpApp(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _appFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        return const AppLoadingScreen();
      },
    );
  }
}

class SerpApp extends ConsumerWidget {
  const SerpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.dark;
    return MaterialApp.router(
      title: 'SERP',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
    );
  }
}
