class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.displayName,
    this.phone,
    this.email,
    this.address,
    this.taxId,
    this.province,
    this.gira,
    this.preferredCarrierId,
    this.customerType = 'CASH',
    this.creditDays,
    this.documentPreference = 'E_INVOICE',
    this.deactivationReason,
    this.isActive = true,
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? displayName;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxId;
  final String? province;
  final String? gira;
  final String? preferredCarrierId;
  final String customerType;
  final int? creditDays;
  final String documentPreference;
  final String? deactivationReason;
  final bool isActive;
  final double creditLimit;
  final double currentBalance;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
