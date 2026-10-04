import '../../domain/entities/expense.dart';
import '../../domain/entities/money_account.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/entities/refund.dart';
import '../../domain/repositories/payment_repository.dart';
import '../data_sources/supabase_payment_data_source.dart';

class SupabasePaymentRepository implements PaymentRepository {
  const SupabasePaymentRepository(this._source);

  final SupabasePaymentDataSource _source;

  @override
  Future<List<Payment>> getPayments() => _source.getPayments();

  @override
  Future<Payment?> getPaymentById(String id) => _source.getPaymentById(id);

  @override
  Future<Payment> createPayment({
    required String customerName,
    required double totalAmount,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    required List<PaymentComponent> components,
  }) => _source.createPayment(
    customerName: customerName,
    totalAmount: totalAmount,
    currencyCode: currencyCode,
    exchangeRate: exchangeRate,
    notes: notes,
    components: components,
  );

  @override
  Future<Payment> confirmPayment(String paymentId) =>
      _source.confirmPayment(paymentId);

  @override
  Future<Payment> cancelPayment(String paymentId, {required String reason}) =>
      _source.cancelPayment(paymentId, reason: reason);

  @override
  Future<List<PaymentMethod>> getPaymentMethods() =>
      _source.getPaymentMethods();

  @override
  Future<PaymentMethod> createPaymentMethod(String name) =>
      _source.createPaymentMethod(name);

  @override
  Future<List<MoneyAccount>> getMoneyAccounts() => _source.getMoneyAccounts();

  @override
  Future<MoneyAccount> createMoneyAccount({
    required String name,
    required MoneyAccountType accountType,
    required String currencyCode,
  }) => _source.createMoneyAccount(
    name: name,
    accountType: accountType,
    currencyCode: currencyCode,
  );

  @override
  Future<Expense> createExpense({
    required String concept,
    required double amount,
    required String currencyCode,
    String? beneficiary,
    String? moneyAccountId,
    DateTime? expenseDate,
  }) => _source.createExpense(
    concept: concept,
    amount: amount,
    currencyCode: currencyCode,
    beneficiary: beneficiary,
    moneyAccountId: moneyAccountId,
    expenseDate: expenseDate,
  );

  @override
  Future<void> transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
  }) => _source.transferBetweenAccounts(
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    amount: amount,
    currencyCode: currencyCode,
    exchangeRate: exchangeRate,
    notes: notes,
  );

  @override
  Future<Refund> createRefund({
    required String paymentId,
    required double amount,
    required String currencyCode,
    required String reason,
  }) => _source.createRefund(
    paymentId: paymentId,
    amount: amount,
    currencyCode: currencyCode,
    reason: reason,
  );
}
