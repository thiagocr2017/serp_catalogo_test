import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/customer.dart';

export '../domain/entities/customer.dart';
export '../domain/repositories/customer_repository.dart';

abstract interface class CustomerApi {
  Future<List<Customer>> getCustomers();
  Future<Customer?> getCustomerById(String id);
  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
  });
  Future<Customer> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
  });
  Future<void> deactivateCustomer(String id);
}

final customerApiProvider = Provider<CustomerApi>(
  (ref) => throw StateError('CustomerApi must be overridden.'),
);

final customersProvider = FutureProvider<List<Customer>>(
  (ref) => ref.watch(customerApiProvider).getCustomers(),
);
