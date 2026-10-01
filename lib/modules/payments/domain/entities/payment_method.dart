class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  final String id;
  final String name;
  final bool isActive;
}
