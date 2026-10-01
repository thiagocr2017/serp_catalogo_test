import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'payment_commands.dart';
import 'payment_dtos.dart';

export 'payment_commands.dart';
export 'payment_dtos.dart';

abstract interface class PaymentApi {
  Future<List<PaymentDto>> getPayments();
  Future<PaymentDto?> getPaymentById(String id);
  Future<PaymentDto> createPayment(CreatePaymentCommand command);
  Future<PaymentDto> confirmPayment(ConfirmPaymentCommand command);
  Future<PaymentDto> cancelPayment(CancelPaymentCommand command);
  Future<List<PaymentMethodDto>> getPaymentMethods();
  Future<PaymentMethodDto> createPaymentMethod(CreatePaymentMethodCommand command);
  Future<List<MoneyAccountDto>> getMoneyAccounts();
  Future<MoneyAccountDto> createMoneyAccount(CreateMoneyAccountCommand command);
  Future<ExpenseDto> createExpense(CreateExpenseCommand command);
  Future<void> transferBetweenAccounts(TransferBetweenAccountsCommand command);
  Future<void> createRefund(CreateRefundCommand command);
}

final paymentApiProvider = Provider<PaymentApi>(
  (ref) => throw StateError('PaymentApi must be overridden.'),
);

final paymentMethodsProvider = FutureProvider<List<PaymentMethodDto>>(
  (ref) => ref.watch(paymentApiProvider).getPaymentMethods(),
);

final moneyAccountsProvider = FutureProvider<List<MoneyAccountDto>>(
  (ref) => ref.watch(paymentApiProvider).getMoneyAccounts(),
);
