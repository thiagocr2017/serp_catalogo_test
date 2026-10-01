import '../../api/payment_api.dart';
import '../../domain/entities/money_account.dart';
import '../../domain/entities/payment.dart';
import '../data_sources/supabase_payment_data_source.dart';

class SupabasePaymentApi implements PaymentApi {
  const SupabasePaymentApi(this._source);

  final SupabasePaymentDataSource _source;

  @override
  Future<List<PaymentDto>> getPayments() async {
    final payments = await _source.getPayments();
    return payments.map(_toDto).toList();
  }

  @override
  Future<PaymentDto?> getPaymentById(String id) async {
    final payment = await _source.getPaymentById(id);
    return payment == null ? null : _toDto(payment);
  }

  @override
  Future<PaymentDto> createPayment(CreatePaymentCommand command) async {
    final payment = await _source.createPayment(
      customerName: command.customerName,
      totalAmount: command.totalAmount,
      currencyCode: command.currencyCode,
      exchangeRate: command.exchangeRate,
      notes: command.notes,
      components: [
        for (final c in command.components)
          PaymentComponent(
            id: '',
            paymentId: '',
            currencyCode: c.currencyCode,
            originalAmount: c.originalAmount,
            usdEquivalent: c.usdEquivalent,
            methodId: c.methodId,
            moneyAccountId: c.moneyAccountId,
            exchangeRate: c.exchangeRate,
            reference: c.reference,
          ),
      ],
    );
    return _toDto(payment);
  }

  @override
  Future<PaymentDto> confirmPayment(ConfirmPaymentCommand command) async {
    final payment = await _source.confirmPayment(command.paymentId);
    return _toDto(payment);
  }

  @override
  Future<PaymentDto> cancelPayment(CancelPaymentCommand command) async {
    final payment = await _source.cancelPayment(
      command.paymentId,
      reason: command.reason,
    );
    return _toDto(payment);
  }

  @override
  Future<List<PaymentMethodDto>> getPaymentMethods() async {
    final methods = await _source.getPaymentMethods();
    return methods
        .map((m) => PaymentMethodDto(id: m.id, name: m.name, isActive: m.isActive))
        .toList();
  }

  @override
  Future<PaymentMethodDto> createPaymentMethod(
    CreatePaymentMethodCommand command,
  ) async {
    final method = await _source.createPaymentMethod(command.name);
    return PaymentMethodDto(id: method.id, name: method.name, isActive: method.isActive);
  }

  @override
  Future<List<MoneyAccountDto>> getMoneyAccounts() async {
    final accounts = await _source.getMoneyAccounts();
    return accounts
        .map(
          (a) => MoneyAccountDto(
            id: a.id,
            name: a.name,
            accountType: switch (a.accountType) {
              MoneyAccountType.cash => 'CASH',
              MoneyAccountType.bank => 'BANK',
              MoneyAccountType.vault => 'VAULT',
              MoneyAccountType.pendingDeposits => 'PENDING_DEPOSITS',
              MoneyAccountType.other => 'OTHER',
            },
            currencyCode: a.currencyCode,
            isActive: a.isActive,
          ),
        )
        .toList();
  }

  @override
  Future<MoneyAccountDto> createMoneyAccount(
    CreateMoneyAccountCommand command,
  ) async {
    final account = await _source.createMoneyAccount(
      name: command.name,
      accountType: switch (command.accountType) {
        'CASH' => MoneyAccountType.cash,
        'BANK' => MoneyAccountType.bank,
        'VAULT' => MoneyAccountType.vault,
        'PENDING_DEPOSITS' => MoneyAccountType.pendingDeposits,
        _ => MoneyAccountType.other,
      },
      currencyCode: command.currencyCode,
    );
    return MoneyAccountDto(
      id: account.id,
      name: account.name,
      accountType: command.accountType,
      currencyCode: account.currencyCode,
      isActive: account.isActive,
    );
  }

  @override
  Future<ExpenseDto> createExpense(CreateExpenseCommand command) async {
    final expense = await _source.createExpense(
      concept: command.concept,
      amount: command.amount,
      currencyCode: command.currencyCode,
      beneficiary: command.beneficiary,
      moneyAccountId: command.moneyAccountId,
      expenseDate: command.expenseDate,
    );
    return ExpenseDto(
      id: expense.id,
      concept: expense.concept,
      amount: expense.amount,
      currencyCode: expense.currencyCode,
      beneficiary: expense.beneficiary,
      expenseDate: expense.expenseDate,
      createdAt: expense.createdAt,
    );
  }

  @override
  Future<void> transferBetweenAccounts(
    TransferBetweenAccountsCommand command,
  ) => _source.transferBetweenAccounts(
    fromAccountId: command.fromAccountId,
    toAccountId: command.toAccountId,
    amount: command.amount,
    currencyCode: command.currencyCode,
    exchangeRate: command.exchangeRate,
    notes: command.notes,
  );

  @override
  Future<void> createRefund(CreateRefundCommand command) async {
    await _source.createRefund(
      paymentId: command.paymentId,
      amount: command.amount,
      currencyCode: command.currencyCode,
      reason: command.reason,
    );
  }

  PaymentDto _toDto(Payment p) => PaymentDto(
    id: p.id,
    status: switch (p.status) {
      PaymentStatus.pending => 'PENDING',
      PaymentStatus.confirmed => 'CONFIRMED',
      PaymentStatus.cancelled => 'CANCELLED',
      PaymentStatus.refunded => 'REFUNDED',
    },
    totalAmount: p.totalAmount,
    currencyCode: p.currencyCode,
    receiptNumber: p.receiptNumber,
    customerName: p.customerName,
    exchangeRate: p.exchangeRate,
    notes: p.notes,
    createdAt: p.createdAt,
  );
}
