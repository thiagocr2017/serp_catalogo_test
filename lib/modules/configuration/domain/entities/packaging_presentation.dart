class PackagingPresentation {
  const PackagingPresentation({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.isActive = true,
  });

  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;
}
