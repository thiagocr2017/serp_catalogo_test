import '../../api/customer_api.dart';
import '../data_sources/supabase_customer_data_source.dart';
import '../mappers/sales_dto_mapper.dart';

class SupabaseCustomerApi implements CustomerApi {
  const SupabaseCustomerApi(this._source);

  final SupabaseCustomerDataSource _source;

  @override
  Future<List<CustomerDto>> getCustomers() async {
    final customers = await _source.getCustomers();
    return customers.map((c) => c.toDto()).toList();
  }

  @override
  Future<CustomerDto?> getCustomerById(String id) async {
    final customer = await _source.getCustomerById(id);
    return customer?.toDto();
  }

  @override
  Future<CustomerDto> createCustomer({
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
  }) async {
    final customer = await _source.createCustomer(
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
    return customer.toDto();
  }

  @override
  Future<CustomerDto> updateCustomer({
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
  }) async {
    final customer = await _source.updateCustomer(
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
    return customer.toDto();
  }

  @override
  Future<void> deactivateCustomer(String id, {String? reason}) =>
      _source.deactivateCustomer(id, reason: reason);

  @override
  Future<List<CustomerContactDto>> getCustomerContacts(String customerId) async {
    final contacts = await _source.getCustomerContacts(customerId);
    return contacts.map((c) => c.toDto()).toList();
  }

  @override
  Future<CustomerContactDto> saveCustomerContact({
    String? id,
    required String customerId,
    required String name,
    String? phone,
    String? role,
    DateTime? birthday,
  }) async {
    final contact = await _source.saveCustomerContact(
      id: id,
      customerId: customerId,
      name: name,
      phone: phone,
      role: role,
      birthday: birthday,
    );
    return contact.toDto();
  }

  @override
  Future<void> deleteCustomerContact(String id) =>
      _source.deleteCustomerContact(id);

  @override
  Future<List<CustomerEmailDto>> getCustomerEmails(String customerId) async {
    final emails = await _source.getCustomerEmails(customerId);
    return emails.map((e) => e.toDto()).toList();
  }

  @override
  Future<CustomerEmailDto> saveCustomerEmail({
    String? id,
    required String customerId,
    required String email,
    CustomerEmailPurpose purpose = CustomerEmailPurpose.copy,
    String? label,
    bool isActive = true,
  }) async {
    final savedEmail = await _source.saveCustomerEmail(
      id: id,
      customerId: customerId,
      email: email,
      purpose: purpose,
      label: label,
      isActive: isActive,
    );
    return savedEmail.toDto();
  }

  @override
  Future<void> deleteCustomerEmail(String id) =>
      _source.deleteCustomerEmail(id);

  @override
  Future<List<ProductBuyerDto>> getProductBuyers(String productId) async {
    final buyers = await _source.getProductBuyers(productId);
    return buyers.map((b) => b.toDto()).toList();
  }

  @override
  Future<CustomerCommercialSummaryDto> getCustomerCommercialSummary(
    String customerId,
  ) =>
      _source.getCustomerCommercialSummary(customerId);

  @override
  Future<List<CustomerCategoryDto>> getCustomerCategories() =>
      _source.getCustomerCategories();
}
