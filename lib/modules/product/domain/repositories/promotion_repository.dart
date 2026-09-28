import '../entities/bulk_promotion.dart';

abstract interface class PromotionRepository {
  Future<List<BulkPromotion>> getPromotions();
  Future<BulkPromotion> createPromotion(
    BulkPromotion promotion, {
    required Set<String> productIds,
    Set<String> categoryIds = const {},
    Map<String, String> productConditions = const {},
  });
  Future<BulkPromotion> updatePromotion(
    BulkPromotion promotion, {
    required Set<String> productIds,
    Set<String> categoryIds = const {},
    Map<String, String> productConditions = const {},
  });
  Future<void> setActive(String id, {required bool isActive});
  Future<void> setProductCondition({
    required String promotionId,
    required String productId,
    required String conditionsText,
  });
}
