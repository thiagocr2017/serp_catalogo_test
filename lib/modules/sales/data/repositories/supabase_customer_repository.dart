import '../../api/customer_api.dart';
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
  }) => _source.createCustomer(
    name: name,
    phone: phone,
    email: email,
    address: address,
    taxId: taxId,
    creditLimit: creditLimit,
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
  }) => _source.updateCustomer(
    id: id,
    name: name,
    phone: phone,
    email: email,
    address: address,
    taxId: taxId,
    creditLimit: creditLimit,
  );

  @override
  Future<void> deactivateCustomer(String id) =>
      _source.deactivateCustomer(id);
}
