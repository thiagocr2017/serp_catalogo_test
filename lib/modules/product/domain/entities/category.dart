class Category {
  const Category({
    required this.id,
    required this.name,
    required this.isActive,
    this.catalogSortOrder = 0,
  });

  final String id;
  final String name;
  final bool isActive;
  final int catalogSortOrder;
}
