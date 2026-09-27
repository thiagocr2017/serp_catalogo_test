class ProductQuery {
  const ProductQuery({
    this.searchTerm,
    this.categoryId,
    this.isActive,
    this.onlyLowStock = false,
    this.minimumPriceInCents,
    this.maximumPriceInCents,
  });

  final String? searchTerm;
  final String? categoryId;
  final bool? isActive;
  final bool onlyLowStock;
  final int? minimumPriceInCents;
  final int? maximumPriceInCents;
}
