class Carrier {
  const Carrier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.contactName,
    this.notes,
    this.isActive = true,
    this.version = 1,
  });

  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? contactName;
  final String? notes;
  final bool isActive;
  final int version;
}
