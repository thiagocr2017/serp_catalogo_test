class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.taxId,
    this.isActive = true,
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxId;
  final bool isActive;
  final double creditLimit;
  final double currentBalance;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
