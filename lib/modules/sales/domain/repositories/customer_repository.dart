import '../entities/customer.dart';

abstract interface class CustomerRepository {
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
  });
  Future<void> deactivateCustomer(String id, {String? reason});
}
