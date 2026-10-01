class PaymentDto {
  const PaymentDto({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    this.receiptNumber,
    this.customerName,
    this.exchangeRate,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String status;
  final double totalAmount;
  final String currencyCode;
  final String? receiptNumber;
  final String? customerName;
  final double? exchangeRate;
  final String? notes;
  final DateTime? createdAt;
}

class PaymentMethodDto {
  const PaymentMethodDto({
    required this.id,
    required this.name,
    this.isActive = true,
  });

  final String id;
  final String name;
  final bool isActive;
}

class MoneyAccountDto {
  const MoneyAccountDto({
    required this.id,
    required this.name,
    required this.accountType,
    required this.currencyCode,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String accountType;
  final String currencyCode;
  final bool isActive;
}

class ExpenseDto {
  const ExpenseDto({
    required this.id,
    required this.concept,
    required this.amount,
    required this.currencyCode,
    this.beneficiary,
    this.expenseDate,
    this.createdAt,
  });

  final String id;
  final String concept;
  final double amount;
  final String currencyCode;
  final String? beneficiary;
  final DateTime? expenseDate;
  final DateTime? createdAt;
}
