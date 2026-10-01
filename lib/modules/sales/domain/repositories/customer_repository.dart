import '../entities/customer.dart';

abstract interface class CustomerRepository {
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
