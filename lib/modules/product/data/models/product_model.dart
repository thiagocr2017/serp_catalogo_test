class ProductModel {
  const ProductModel(this.data);

  final Map<String, dynamic> data;

  String get id => data['id'] as String;
  String get sku => data['sku'] as String;
  String? get barcode => data['barcode'] as String?;
  String get name => data['name'] as String;
  String get description => data['description'] as String;
  String get categoryId => data['category_id'] as String;
  int get unitPriceInCents => _moneyToCents(data['unit_price']);
  int? get packagePriceInCents => data['package_price'] == null
      ? null
      : _moneyToCents(data['package_price']);
  int get minimumOrderQuantity => data['min_order_quantity'] as int;
  int get minimumSaleQuantity => data['minimum_sale_quantity'] as int? ?? 1;
  String get packagingPresentationId =>
      data['packaging_presentation_id'] as String;
  String? get packagingPresentationName =>
      data['packaging_presentation_name'] as String?;
  double get cbmPerMoq => _asDouble(data['cbm_per_moq']);
  int get factoryCostInCents => _moneyToCents(data['factory_cost']);
  int get extraCostsInCents =>
      data['extra_costs'] == null ? 0 : _moneyToCents(data['extra_costs']);
  String? get imageUrl => data['image_url'] as String?;
  double get imagePositionX => _asDouble(data['image_position_x'] ?? 0.5);
  double get imagePositionY => _asDouble(data['image_position_y'] ?? 0.5);
  double get imageScale => _asDouble(data['image_scale'] ?? 1);
  int get catalogSortOrder => data['catalog_sort_order'] as int? ?? 0;
  int get currentStock => data['current_stock'] as int;
  int get reorderPoint => data['reorder_point'] as int;
  int? get promotionPriceInCents =>
      data['promo_price'] == null ? null : _moneyToCents(data['promo_price']);
  String? get promotionText => data['promo_text'] as String?;
  String? get promotionType => data['promotion_type'] as String?;
  String? get bulkPromotionId => data['bulk_promotion_id'] as String?;
  String? get bulkPromotionName => data['bulk_promotion_name'] as String?;
  String? get bulkPromotionConditions =>
      data['bulk_promotion_conditions'] as String?;
  String? get bulkProductConditions =>
      data['bulk_product_conditions'] as String?;
  bool get isActive => data['is_active'] as bool;
  DateTime get createdAt => DateTime.parse(data['created_at'] as String);
  DateTime? get updatedAt => _optionalDate(data['updated_at']);
  DateTime? get deletedAt => _optionalDate(data['deleted_at']);

  static int _moneyToCents(Object? value) => (_asDouble(value) * 100).round();

  static double _asDouble(Object? value) => switch (value) {
    num number => number.toDouble(),
    String text => double.parse(text),
    _ => throw FormatException('Expected a numeric value, received $value'),
  };

  static DateTime? _optionalDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
