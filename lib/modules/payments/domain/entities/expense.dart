class Expense {
  const Expense({
    required this.id,
    required this.concept,
    required this.amount,
    required this.currencyCode,
    this.beneficiary,
    this.moneyAccountId,
    this.expenseDate,
    this.createdAt,
  });

  final String id;
  final String concept;
  final double amount;
  final String currencyCode;
  final String? beneficiary;
  final String? moneyAccountId;
  final DateTime? expenseDate;
  final DateTime? createdAt;
}
