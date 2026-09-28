import '../entities/bulk_promotion.dart';

abstract interface class PromotionRepository {
  Future<List<BulkPromotion>> getPromotions();
  Future<BulkPromotion> createPromotion(
    BulkPromotion promotion, {
    required Set<String> productIds,
    Map<String, String> productConditions = const {},
  });
  Future<void> setActive(String id, {required bool isActive});
}
