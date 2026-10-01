import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/device/device_identity.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/entities/money_account.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/refund.dart';

class SupabasePaymentDataSource {
  const SupabasePaymentDataSource(this._client, this._device);

  final SupabaseClient _client;
  final DeviceIdentity _device;

  Future<List<Payment>> getPayments() async {
    final rows = await _client
        .from('payments')
        .select('*, payment_components(*)')
        .order('created_at', ascending: false);
    return rows.map(_payment).toList();
  }

  Future<Payment?> getPaymentById(String id) async {
    final row = await _client
        .from('payments')
        .select('*, payment_components(*)')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _payment(row);
  }

  Future<Payment> createPayment({
    required String customerName,
    required double totalAmount,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    required List<PaymentComponent> components,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_payment',
      params: {
        'p_command_id': const Uuid().v4(),
        'p_customer_name': customerName,
        'p_total_amount': totalAmount,
        'p_currency_code': currencyCode,
        'p_exchange_rate': exchangeRate,
        'p_notes': notes,
        'p_components': [
          for (final c in components)
            {
              'method_id': c.methodId,
              'money_account_id': c.moneyAccountId,
              'currency_code': c.currencyCode,
              'original_amount': c.originalAmount,
              'exchange_rate': c.exchangeRate,
              'usd_equivalent': c.usdEquivalent,
              'reference': c.reference,
            },
        ],
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _payment(row);
  }

  Future<Payment> confirmPayment(String paymentId) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'confirm_payment',
      params: {
        'p_payment_id': paymentId,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _payment(row);
  }

  Future<Payment> cancelPayment(String paymentId, {required String reason}) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'cancel_payment',
      params: {
        'p_payment_id': paymentId,
        'p_reason': reason,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _payment(row);
  }

  Future<List<PaymentMethod>> getPaymentMethods() async {
    final rows = await _client
        .from('payment_methods')
        .select()
        .eq('is_active', true)
        .order('name');
    return rows.map(_method).toList();
  }

  Future<PaymentMethod> createPaymentMethod(String name) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_payment_method',
      params: {
        'p_name': name,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _method(row);
  }

  Future<List<MoneyAccount>> getMoneyAccounts() async {
    final rows = await _client
        .from('money_accounts')
        .select()
        .eq('is_active', true)
        .order('name');
    return rows.map(_account).toList();
  }

  Future<MoneyAccount> createMoneyAccount({
    required String name,
    required MoneyAccountType accountType,
    required String currencyCode,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_money_account',
      params: {
        'p_name': name,
        'p_account_type': switch (accountType) {
          MoneyAccountType.cash => 'CASH',
          MoneyAccountType.bank => 'BANK',
          MoneyAccountType.vault => 'VAULT',
          MoneyAccountType.pendingDeposits => 'PENDING_DEPOSITS',
          MoneyAccountType.other => 'OTHER',
        },
        'p_currency_code': currencyCode,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _account(row);
  }

  Future<Expense> createExpense({
    required String concept,
    required double amount,
    required String currencyCode,
    String? beneficiary,
    String? moneyAccountId,
    DateTime? expenseDate,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_expense',
      params: {
        'p_concept': concept,
        'p_beneficiary': beneficiary,
        'p_amount': amount,
        'p_currency_code': currencyCode,
        'p_money_account_id': moneyAccountId,
        'p_expense_date': expenseDate?.toIso8601String().split('T').first,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _expense(row);
  }

  Future<void> transferBetweenAccounts({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
  }) => _client.rpc<void>(
    'transfer_between_accounts',
    params: {
      'p_from_account_id': fromAccountId,
      'p_to_account_id': toAccountId,
      'p_amount': amount,
      'p_currency_code': currencyCode,
      'p_exchange_rate': exchangeRate,
      'p_notes': notes,
      'p_actor_name': _device.actorName,
      'p_device_name': _device.name,
      'p_device_identifier': _device.identifier,
    },
  );

  Future<Refund> createRefund({
    required String paymentId,
    required double amount,
    required String currencyCode,
    required String reason,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_refund',
      params: {
        'p_payment_id': paymentId,
        'p_amount': amount,
        'p_currency_code': currencyCode,
        'p_reason': reason,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _refund(row);
  }

  Payment _payment(Map<String, dynamic> row) {
    final components = (row['payment_components'] as List<dynamic>?)
            ?.map((c) => _component(c as Map<String, dynamic>))
            .toList() ??
        const [];
    return Payment(
      id: row['id'] as String,
      status: switch (row['status'] as String) {
        'PENDING' => PaymentStatus.pending,
        'CONFIRMED' => PaymentStatus.confirmed,
        'CANCELLED' => PaymentStatus.cancelled,
        'REFUNDED' => PaymentStatus.refunded,
        _ => PaymentStatus.pending,
      },
      totalAmount: (row['total_amount'] as num).toDouble(),
      currencyCode: row['currency_code'] as String,
      receiptNumber: row['receipt_number'] as String?,
      customerName: row['customer_name'] as String?,
      customerId: row['customer_id'] as String?,
      exchangeRate: (row['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      notes: row['notes'] as String?,
      components: components,
      createdAt: row['created_at'] == null
          ? null
          : DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] == null
          ? null
          : DateTime.parse(row['updated_at'] as String),
    );
  }

  PaymentComponent _component(Map<String, dynamic> row) => PaymentComponent(
    id: row['id'] as String,
    paymentId: row['payment_id'] as String,
    currencyCode: row['currency_code'] as String,
    originalAmount: (row['original_amount'] as num).toDouble(),
    usdEquivalent: (row['usd_equivalent'] as num).toDouble(),
    methodId: row['method_id'] as String?,
    moneyAccountId: row['money_account_id'] as String?,
    exchangeRate: (row['exchange_rate'] as num?)?.toDouble() ?? 1.0,
    reference: row['reference'] as String?,
  );

  PaymentMethod _method(Map<String, dynamic> row) => PaymentMethod(
    id: row['id'] as String,
    name: row['name'] as String,
    isActive: row['is_active'] as bool? ?? true,
  );

  MoneyAccount _account(Map<String, dynamic> row) => MoneyAccount(
    id: row['id'] as String,
    name: row['name'] as String,
    accountType: switch (row['account_type'] as String) {
      'CASH' => MoneyAccountType.cash,
      'BANK' => MoneyAccountType.bank,
      'VAULT' => MoneyAccountType.vault,
      'PENDING_DEPOSITS' => MoneyAccountType.pendingDeposits,
      _ => MoneyAccountType.other,
    },
    currencyCode: row['currency_code'] as String,
    isActive: row['is_active'] as bool? ?? true,
  );

  Expense _expense(Map<String, dynamic> row) => Expense(
    id: row['id'] as String,
    concept: row['concept'] as String,
    amount: (row['amount'] as num).toDouble(),
    currencyCode: row['currency_code'] as String,
    beneficiary: row['beneficiary'] as String?,
    moneyAccountId: row['money_account_id'] as String?,
    expenseDate: row['expense_date'] == null
        ? null
        : DateTime.parse(row['expense_date'] as String),
    createdAt: row['created_at'] == null
        ? null
        : DateTime.parse(row['created_at'] as String),
  );

  Refund _refund(Map<String, dynamic> row) => Refund(
    id: row['id'] as String,
    paymentId: row['payment_id'] as String,
    amount: (row['amount'] as num).toDouble(),
    currencyCode: row['currency_code'] as String,
    reason: row['reason'] as String,
    status: switch (row['status'] as String) {
      'PENDING' => RefundStatus.pending,
      'CONFIRMED' => RefundStatus.confirmed,
      'REJECTED' => RefundStatus.rejected,
      _ => RefundStatus.pending,
    },
    createdAt: row['created_at'] == null
        ? null
        : DateTime.parse(row['created_at'] as String),
  );
}
