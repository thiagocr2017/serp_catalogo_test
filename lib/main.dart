import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/configuration/app_configuration.dart';
import 'core/navigation/app_router.dart';
import 'modules/product/data/data_sources/supabase_product_data_source.dart';
import 'modules/product/data/repositories/supabase_product_repository.dart';
import 'modules/product/di/product_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configuration = AppConfiguration.local();
  await Supabase.initialize(
    url: configuration.supabaseUrl,
    publishableKey: configuration.supabaseKey,
  );
  final repository = SupabaseProductRepository(
    SupabaseProductDataSource(Supabase.instance.client),
  );

  runApp(
    ProviderScope(
      overrides: [productRepositoryProvider.overrideWithValue(repository)],
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
