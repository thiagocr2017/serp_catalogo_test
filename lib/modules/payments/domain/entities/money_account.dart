enum MoneyAccountType { cash, bank, vault, pendingDeposits, other }

class MoneyAccount {
  const MoneyAccount({
    required this.id,
    required this.name,
    required this.accountType,
    required this.currencyCode,
    this.isActive = true,
  });

  final String id;
  final String name;
  final MoneyAccountType accountType;
  final String currencyCode;
  final bool isActive;
}
