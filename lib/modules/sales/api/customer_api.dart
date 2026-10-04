import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_category_dtos.dart';
import 'customer_dtos.dart';
import 'customer_summary_dtos.dart';

export 'customer_category_dtos.dart';
export 'customer_dtos.dart';
export 'customer_summary_dtos.dart';

abstract interface class CustomerApi {
  Future<List<CustomerDto>> getCustomers();
  Future<CustomerDto?> getCustomerById(String id);
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
    String customerType,
    int? creditDays,
    String documentPreference,
    bool requiresEInvoice,
    String shippingPaymentPolicy,
    List<String> categoryIds,
  });
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
    String customerType,
    int? creditDays,
    String documentPreference,
    bool requiresEInvoice,
    String shippingPaymentPolicy,
    List<String>? categoryIds,
  });
  Future<void> deactivateCustomer(String id, {String? reason});

  Future<List<CustomerContactDto>> getCustomerContacts(String customerId);
  Future<CustomerContactDto> saveCustomerContact({
    String? id,
    required String customerId,
    required String name,
    String? phone,
    String? role,
    DateTime? birthday,
  });
  Future<void> deleteCustomerContact(String id);

  Future<List<CustomerEmailDto>> getCustomerEmails(String customerId);
  Future<CustomerEmailDto> saveCustomerEmail({
    String? id,
    required String customerId,
    required String email,
    CustomerEmailPurpose purpose,
    String? label,
    bool isActive,
  });
  Future<void> deleteCustomerEmail(String id);

  Future<List<ProductBuyerDto>> getProductBuyers(String productId);
  Future<CustomerCommercialSummaryDto> getCustomerCommercialSummary(String customerId);
  Future<List<CustomerCategoryDto>> getCustomerCategories();
  Future<CustomerCategoryDto> createCustomerCategory({
    required String name,
    String? description,
    String? color,
  });
  Future<CustomerCategoryDto> updateCustomerCategory({
    required String id,
    required String name,
    String? description,
    String? color,
    bool isActive = true,
  });
  Future<void> deleteCustomerCategory(String id);
}

final customerApiProvider = Provider<CustomerApi>(
  (ref) => throw StateError('CustomerApi must be overridden.'),
);

final customersProvider = FutureProvider<List<CustomerDto>>(
  (ref) => ref.watch(customerApiProvider).getCustomers(),
);

final productBuyersProvider = FutureProvider.family<List<ProductBuyerDto>, String>(
  (ref, productId) =>
      ref.watch(customerApiProvider).getProductBuyers(productId),
);
