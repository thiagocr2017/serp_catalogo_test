class BulkPromotion {
  const BulkPromotion({
    required this.id,
    required this.name,
    required this.discountPercentage,
    required this.conditionsText,
    required this.endDate,
    required this.appliesToAllProducts,
    required this.isActive,
    this.startDate,
    this.badgeImageUrl,
    this.productIds = const {},
    this.categoryIds = const {},
    this.productConditions = const {},
  });
  final String id;
  final String name;
  final double discountPercentage;
  final String conditionsText;
  final String? badgeImageUrl;
  final DateTime? startDate;
  final DateTime endDate;
  final bool appliesToAllProducts;
  final bool isActive;
  final Set<String> productIds;
  final Set<String> categoryIds;
  final Map<String, String> productConditions;
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive &&
        (startDate == null || !now.isBefore(startDate!)) &&
        now.isBefore(endDate);
  }
}
