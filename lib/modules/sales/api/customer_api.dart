import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/customer.dart';
import '../domain/entities/customer_commercial.dart';
import '../domain/entities/customer_email.dart';

export '../domain/entities/customer.dart';
export '../domain/entities/customer_commercial.dart';
export '../domain/entities/customer_email.dart';

abstract interface class CustomerApi {
  Future<List<Customer>> getCustomers();
  Future<Customer?> getCustomerById(String id);
  Future<Customer> createCustomer({
    required String name,
    String? displayName,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
    String? province,
    String? gira,
    String? preferredCarrierId,
    String? identificationTypeId,
    String? economicActivity,
    String customerType,
    int? creditDays,
    String documentPreference,
    bool requiresEInvoice,
  });
  Future<Customer> updateCustomer({
    required String id,
    required String name,
    String? displayName,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
    String? province,
    String? gira,
    String? preferredCarrierId,
    String? identificationTypeId,
    String? economicActivity,
    String customerType,
    int? creditDays,
    String documentPreference,
    bool requiresEInvoice,
  });
  Future<void> deactivateCustomer(String id, {String? reason});

  Future<List<CustomerContact>> getCustomerContacts(String customerId);
  Future<CustomerContact> saveCustomerContact({
    String? id,
    required String customerId,
    required String name,
    String? phone,
    String? role,
    DateTime? birthday,
  });
  Future<void> deleteCustomerContact(String id);

  Future<List<CustomerEmail>> getCustomerEmails(String customerId);
  Future<CustomerEmail> saveCustomerEmail({
    String? id,
    required String customerId,
    required String email,
    CustomerEmailPurpose purpose,
    String? label,
    bool isActive,
  });
  Future<void> deleteCustomerEmail(String id);

  Future<List<ProductBuyer>> getProductBuyers(String productId);
}

final customerApiProvider = Provider<CustomerApi>(
  (ref) => throw StateError('CustomerApi must be overridden.'),
);

final customersProvider = FutureProvider<List<Customer>>(
  (ref) => ref.watch(customerApiProvider).getCustomers(),
);

final productBuyersProvider = FutureProvider.family<List<ProductBuyer>, String>(
  (ref, productId) =>
      ref.watch(customerApiProvider).getProductBuyers(productId),
);
