import '../entities/payment.dart';
import '../entities/payment_method.dart';
import '../entities/money_account.dart';
import '../entities/expense.dart';
import '../entities/refund.dart';

abstract interface class PaymentRepository {
  Future<List<Payment>> getPayments();
  Future<Payment?> getPaymentById(String id);
  Future<Payment> createPayment({
    required String customerName,
    required double totalAmount,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    required List<PaymentComponent> components,
  });
  Future<Payment> confirmPayment(String paymentId);
  Future<Payment> cancelPayment(String paymentId, {required String reason});
  Future<List<PaymentMethod>> getPaymentMethods();
  Future<PaymentMethod> createPaymentMethod(String name);
  Future<List<MoneyAccount>> getMoneyAccounts();
  Future<MoneyAccount> createMoneyAccount({
    required String name,
    required MoneyAccountType accountType,
    required String currencyCode,
  });
  Future<Expense> createExpense({
    required String concept,
    required double amount,
    required String currencyCode,
    String? beneficiary,
    String? moneyAccountId,
    DateTime? expenseDate,
  });
  Future<void> transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
  });
  Future<Refund> createRefund({
    required String paymentId,
    required double amount,
    required String currencyCode,
    required String reason,
  });
}
