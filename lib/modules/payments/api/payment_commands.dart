import '../../../core/identity/identity_context.dart';

class CreatePaymentCommand {
  const CreatePaymentCommand({
    required this.customerName,
    required this.totalAmount,
    required this.currencyCode,
    required this.exchangeRate,
    this.notes,
    required this.components,
    required this.identity,
  });

  final String customerName;
  final double totalAmount;
  final String currencyCode;
  final double exchangeRate;
  final String? notes;
  final List<PaymentComponentInput> components;
  final IdentityContext identity;
}

class PaymentComponentInput {
  const PaymentComponentInput({
    this.methodId,
    this.moneyAccountId,
    required this.currencyCode,
    required this.originalAmount,
    required this.exchangeRate,
    required this.usdEquivalent,
    this.reference,
  });

  final String? methodId;
  final String? moneyAccountId;
  final String currencyCode;
  final double originalAmount;
  final double exchangeRate;
  final double usdEquivalent;
  final String? reference;
}

class ConfirmPaymentCommand {
  const ConfirmPaymentCommand({
    required this.paymentId,
    required this.identity,
  });

  final String paymentId;
  final IdentityContext identity;
}

class CancelPaymentCommand {
  const CancelPaymentCommand({
    required this.paymentId,
    required this.reason,
    required this.identity,
  });

  final String paymentId;
  final String reason;
  final IdentityContext identity;
}

class CreatePaymentMethodCommand {
  const CreatePaymentMethodCommand({
    required this.name,
    required this.identity,
  });

  final String name;
  final IdentityContext identity;
}

class CreateMoneyAccountCommand {
  const CreateMoneyAccountCommand({
    required this.name,
    required this.accountType,
    required this.currencyCode,
    required this.identity,
  });

  final String name;
  final String accountType;
  final String currencyCode;
  final IdentityContext identity;
}

class CreateExpenseCommand {
  const CreateExpenseCommand({
    required this.concept,
    required this.amount,
    required this.currencyCode,
    this.beneficiary,
    this.moneyAccountId,
    this.expenseDate,
    required this.identity,
  });

  final String concept;
  final double amount;
  final String currencyCode;
  final String? beneficiary;
  final String? moneyAccountId;
  final DateTime? expenseDate;
  final IdentityContext identity;
}

class TransferBetweenAccountsCommand {
  const TransferBetweenAccountsCommand({
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.currencyCode,
    required this.exchangeRate,
    this.notes,
    required this.identity,
  });

  final String fromAccountId;
  final String toAccountId;
  final double amount;
  final String currencyCode;
  final double exchangeRate;
  final String? notes;
  final IdentityContext identity;
}

class CreateRefundCommand {
  const CreateRefundCommand({
    required this.paymentId,
    required this.amount,
    required this.currencyCode,
    required this.reason,
    required this.identity,
  });

  final String paymentId;
  final double amount;
  final String currencyCode;
  final String reason;
  final IdentityContext identity;
}
