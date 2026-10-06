class PackagingPresentation {
  const PackagingPresentation({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.unitsPerPresentation = 1,
    this.isActive = true,
  });

  final String id;
  final String name;
  final int sortOrder;
  final int unitsPerPresentation;
  final bool isActive;
}
