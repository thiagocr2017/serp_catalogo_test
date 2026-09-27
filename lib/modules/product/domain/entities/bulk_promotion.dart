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
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive &&
        (startDate == null || !now.isBefore(startDate!)) &&
        now.isBefore(endDate);
  }
}
