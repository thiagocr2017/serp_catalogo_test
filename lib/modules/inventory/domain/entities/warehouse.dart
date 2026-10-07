class Warehouse {
  const Warehouse({
    required this.id,
    required this.code,
    required this.name,
    required this.isDefault,
    required this.isActive,
    this.locations = const [],
  });

  final String id;
  final String code;
  final String name;
  final bool isDefault;
  final bool isActive;
  final List<InventoryLocation> locations;
}

class InventoryLocation {
  const InventoryLocation({
    required this.id,
    required this.warehouseId,
    required this.code,
    required this.name,
    required this.isDefault,
    required this.isActive,
    this.stockRole = 'SELLABLE',
  });

  final String id;
  final String warehouseId;
  final String code;
  final String name;
  final bool isDefault;
  final bool isActive;
  final String stockRole;
}
