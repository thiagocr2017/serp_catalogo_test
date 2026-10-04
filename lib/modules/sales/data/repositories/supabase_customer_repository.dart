import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../data_sources/supabase_customer_data_source.dart';

class SupabaseCustomerRepository implements CustomerRepository {
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
    String countryCode = 'CR',
    String? province,
    String? city,
    String? gira,
    String? preferredCarrierId,
    String? identificationTypeId,
    String? economicActivity,
    String customerType = 'CASH',
    int? creditDays,
    String documentPreference = 'E_INVOICE',
    bool requiresEInvoice = false,
    String shippingPaymentPolicy = 'INCLUDED',
    List<String> categoryIds = const [],
  }) => _source.createCustomer(
    name: name,
    displayName: displayName,
    phone: phone,
    email: email,
    address: address,
    taxId: taxId,
    creditLimit: creditLimit,
    countryCode: countryCode,
    province: province,
    city: city,
    gira: gira,
    preferredCarrierId: preferredCarrierId,
    identificationTypeId: identificationTypeId,
    economicActivity: economicActivity,
    customerType: customerType,
    creditDays: creditDays,
    documentPreference: documentPreference,
    requiresEInvoice: requiresEInvoice,
    shippingPaymentPolicy: shippingPaymentPolicy,
    categoryIds: categoryIds,
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
    String countryCode = 'CR',
    String? province,
    String? city,
    String? gira,
    String? preferredCarrierId,
    String? identificationTypeId,
    String? economicActivity,
    String customerType = 'CASH',
    int? creditDays,
    String documentPreference = 'E_INVOICE',
    bool requiresEInvoice = false,
    String shippingPaymentPolicy = 'INCLUDED',
    List<String>? categoryIds,
  }) => _source.updateCustomer(
    id: id,
    name: name,
    displayName: displayName,
    phone: phone,
    email: email,
    address: address,
    taxId: taxId,
    creditLimit: creditLimit,
    countryCode: countryCode,
    province: province,
    city: city,
    gira: gira,
    preferredCarrierId: preferredCarrierId,
    identificationTypeId: identificationTypeId,
    economicActivity: economicActivity,
    customerType: customerType,
    creditDays: creditDays,
    documentPreference: documentPreference,
    requiresEInvoice: requiresEInvoice,
    shippingPaymentPolicy: shippingPaymentPolicy,
    categoryIds: categoryIds,
  );

  @override
  Future<void> deactivateCustomer(String id, {String? reason}) =>
      _source.deactivateCustomer(id, reason: reason);
}
