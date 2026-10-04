import '../../api/customer_api.dart';
import '../../domain/repositories/customer_repository.dart';
import '../data_sources/supabase_customer_data_source.dart';

class SupabaseCustomerRepository implements CustomerRepository, CustomerApi {
  const SupabaseCustomerRepository(this._source);

  final SupabaseCustomerDataSource _source;

  @override
  Future<List<Customer>> getCustomers() => _source.getCustomers();

  @override
  Future<Customer?> getCustomerById(String id) => _source.getCustomerById(id);

  @override
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
    String customerType = 'CASH',
    int? creditDays,
    String documentPreference = 'E_INVOICE',
  }) => _source.createCustomer(
    name: name,
    displayName: displayName,
    phone: phone,
    email: email,
    address: address,
    taxId: taxId,
    creditLimit: creditLimit,
    province: province,
    gira: gira,
    preferredCarrierId: preferredCarrierId,
    customerType: customerType,
    creditDays: creditDays,
    documentPreference: documentPreference,
  );

  @override
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
    String customerType = 'CASH',
    int? creditDays,
    String documentPreference = 'E_INVOICE',
  }) => _source.updateCustomer(
    id: id,
    name: name,
    displayName: displayName,
    phone: phone,
    email: email,
    address: address,
    taxId: taxId,
    creditLimit: creditLimit,
    province: province,
    gira: gira,
    preferredCarrierId: preferredCarrierId,
    customerType: customerType,
    creditDays: creditDays,
    documentPreference: documentPreference,
  );

  @override
  Future<void> deactivateCustomer(String id, {String? reason}) =>
      _source.deactivateCustomer(id, reason: reason);

  @override
  Future<List<CustomerContact>> getCustomerContacts(String customerId) =>
      _source.getCustomerContacts(customerId);

  @override
  Future<CustomerContact> saveCustomerContact({
    String? id,
    required String customerId,
    required String name,
    String? phone,
    String? role,
    DateTime? birthday,
  }) => _source.saveCustomerContact(
    id: id,
    customerId: customerId,
    name: name,
    phone: phone,
    role: role,
    birthday: birthday,
  );

  @override
  Future<void> deleteCustomerContact(String id) =>
      _source.deleteCustomerContact(id);

  @override
  Future<List<ProductBuyer>> getProductBuyers(String productId) =>
      _source.getProductBuyers(productId);
}
