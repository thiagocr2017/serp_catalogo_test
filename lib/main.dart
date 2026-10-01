import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/configuration/app_configuration.dart';
import 'core/configuration/theme_mode_controller.dart';
import 'core/navigation/app_router.dart';
import 'core/device/device_identity.dart';
import 'core/identity/identity_context.dart';
import 'core/identity/identity_context_provider.dart';
import 'core/offline/data/offline_queue_repository.dart';
import 'core/offline/services/offline_sync_service.dart';
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
import 'modules/sales/data/data_sources/supabase_sales_invoice_data_source.dart';
import 'modules/sales/data/repositories/supabase_sales_invoice_repository.dart';
import 'modules/sales/api/sales_invoice_api.dart';
import 'modules/sales/data/data_sources/supabase_customer_data_source.dart';
import 'modules/sales/data/repositories/supabase_customer_repository.dart';
import 'modules/sales/api/customer_api.dart';
import 'modules/sales/data/data_sources/supabase_quote_data_source.dart';
import 'modules/sales/data/repositories/supabase_quote_repository.dart';
import 'modules/sales/api/quote_api.dart';
import 'modules/sales/data/data_sources/supabase_order_data_source.dart';
import 'modules/sales/data/repositories/supabase_order_repository.dart';
import 'modules/sales/api/order_api.dart';
import 'modules/sales/data/data_sources/supabase_return_data_source.dart';
import 'modules/sales/data/repositories/supabase_return_repository.dart';
import 'modules/sales/api/return_api.dart';
import 'modules/sales/data/data_sources/supabase_consignment_data_source.dart';
import 'modules/sales/data/repositories/supabase_consignment_repository.dart';
import 'modules/sales/api/consignment_api.dart';
import 'modules/sales/di/sales_providers.dart';
import 'modules/sales/sales_module.dart';
import 'modules/payments/data/data_sources/supabase_payment_data_source.dart';
import 'modules/payments/data/repositories/supabase_payment_repository.dart';
import 'modules/payments/data/repositories/supabase_payment_api.dart';
import 'modules/payments/di/payment_providers.dart';
import 'modules/payments/payments_module.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _LoadingScreen());

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
  final salesInvoiceRepository = SupabaseSalesInvoiceRepository(
    SupabaseSalesInvoiceDataSource(Supabase.instance.client, device),
  );
  final customerRepository = SupabaseCustomerRepository(
    SupabaseCustomerDataSource(Supabase.instance.client, device),
  );
  final quoteRepository = SupabaseQuoteRepository(
    SupabaseQuoteDataSource(Supabase.instance.client, device),
  );
  final orderRepository = SupabaseOrderRepository(
    SupabaseOrderDataSource(Supabase.instance.client, device),
  );
  final returnRepository = SupabaseReturnRepository(
    SupabaseReturnDataSource(Supabase.instance.client, device),
  );
  final consignmentRepository = SupabaseConsignmentRepository(
    SupabaseConsignmentDataSource(Supabase.instance.client, device),
  );
  final paymentDataSource = SupabasePaymentDataSource(
    Supabase.instance.client,
    device,
  );
  final paymentRepository = SupabasePaymentRepository(paymentDataSource);
  final paymentApi = SupabasePaymentApi(paymentDataSource);
  final offlineSyncService = OfflineSyncService(
    OfflineQueueRepository.instance,
    device,
  );

  runApp(
    ProviderScope(
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
        salesInvoiceApiProvider.overrideWithValue(salesInvoiceRepository),
        customerApiProvider.overrideWithValue(customerRepository),
        quoteApiProvider.overrideWithValue(quoteRepository),
        orderApiProvider.overrideWithValue(orderRepository),
        returnApiProvider.overrideWithValue(returnRepository),
        consignmentApiProvider.overrideWithValue(consignmentRepository),
        paymentRepositoryProvider.overrideWithValue(paymentRepository),
        paymentApiProvider.overrideWithValue(paymentApi),
        offlineSyncServiceProvider.overrideWithValue(offlineSyncService),
      ],
      child: const SerpApp(),
    ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64),
              SizedBox(height: 16),
              Text(
                'SERP',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(minHeight: 4),
              ),
              SizedBox(height: 16),
              Text('Iniciando...'),
            ],
          ),
        ),
      ),
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
