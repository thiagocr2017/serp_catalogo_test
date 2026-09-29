import 'dart:typed_data';

import '../entities/business_settings.dart';
import '../entities/catalog_preferences.dart';
import '../entities/packaging_presentation.dart';

abstract interface class ConfigurationRepository {
  Future<BusinessSettings> get();

  Future<void> save(BusinessSettings value);

  Future<void> purgeTestDataAndGoProduction();

  Future<CatalogPreferences> getCatalogPreferences();

  Future<void> saveCatalogPreferences(CatalogPreferences value);

  Future<void> setCatalogLogoUrl(String url);

  Future<String> uploadCatalogLogo(Uint8List bytes, String extension);

  Future<Uint8List?> downloadCatalogLogo(String? url);

  Future<List<PackagingPresentation>> getPackagingPresentations();

  Future<PackagingPresentation> savePackagingPresentation({
    String? id,
    required String name,
  });
}
