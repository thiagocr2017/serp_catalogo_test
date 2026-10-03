import '../../api/customer_api.dart';
import '../../domain/repositories/customer_repository.dart';
import '../data_sources/supabase_customer_data_source.dart';

class SupabaseCustomerRepository
    implements CustomerRepository, CustomerApi {
  const SupabaseCustomerRepository(this._source);

  final SupabaseCustomerDataSource _source;

  @override
  Future<List<Customer>> getCustomers() => _source.getCustomers();

  @override
  Future<Customer?> getCustomerById(String id) =>
      _source.getCustomerById(id);

  @override
  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
    String? province,
    String? gira,
  }) => _source.createCustomer(
    name: name,
    phone: phone,
    email: email,
    address: address,
    taxId: taxId,
    creditLimit: creditLimit,
    province: province,
    gira: gira,
  );

  @override
  Future<Customer> updateCustomer({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
    String? province,
    String? gira,
  }) => _source.updateCustomer(
    id: id,
    name: name,
    phone: phone,
    email: email,
    address: address,
    taxId: taxId,
    creditLimit: creditLimit,
    province: province,
    gira: gira,
  );

  @override
  Future<void> deactivateCustomer(String id) =>
      _source.deactivateCustomer(id);

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
  }) => _source.saveCustomerContact(
    id: id,
    customerId: customerId,
    name: name,
    phone: phone,
    role: role,
  );

  @override
  Future<void> deleteCustomerContact(String id) =>
      _source.deleteCustomerContact(id);

  @override
  Future<List<ProductBuyer>> getProductBuyers(String productId) =>
      _source.getProductBuyers(productId);
}
