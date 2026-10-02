import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/device_identity.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_commercial.dart';

class SupabaseCustomerDataSource {
  const SupabaseCustomerDataSource(this._client, this._device);

  final SupabaseClient _client;
  final DeviceIdentity _device;

  Future<List<Customer>> getCustomers() async {
    final rows = await _client
        .from('customers')
        .select()
        .order('name');
    return rows.map(_customer).toList();
  }

  Future<Customer?> getCustomerById(String id) async {
    final row = await _client
        .from('customers')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : _customer(row);
  }

  Future<Customer> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxId,
    double? creditLimit,
    String? province,
    String? gira,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_customer',
      params: {
        'p_name': name,
        'p_phone': phone,
        'p_email': email,
        'p_address': address,
        'p_tax_id': taxId,
        'p_credit_limit': creditLimit,
        'p_province': province,
        'p_gira': gira,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _customer(row);
  }

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
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'update_customer',
      params: {
        'p_customer_id': id,
        'p_name': name,
        'p_phone': phone,
        'p_email': email,
        'p_address': address,
        'p_tax_id': taxId,
        'p_credit_limit': creditLimit,
        'p_province': province,
        'p_gira': gira,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _customer(row);
  }

  Future<void> deactivateCustomer(String id) async {
    await _client.rpc(
      'deactivate_customer',
      params: {
        'p_customer_id': id,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
  }

  Future<List<CustomerContact>> getCustomerContacts(String customerId) async {
    final rows = await _client
        .from('customer_contacts')
        .select()
        .eq('customer_id', customerId)
        .order('name');
    return rows.map(_contact).toList();
  }

  Future<CustomerContact> saveCustomerContact({
    String? id,
    required String customerId,
    required String name,
    String? phone,
    String? role,
  }) async {
    if (id == null) {
      final row = await _client.rpc<Map<String, dynamic>>(
        'create_customer_contact',
        params: {
          'p_customer_id': customerId,
          'p_name': name,
          'p_phone': phone,
          'p_role': role,
          'p_actor_name': _device.actorName,
          'p_device_name': _device.name,
          'p_device_identifier': _device.identifier,
        },
      );
      return _contact(row);
    }
    final row = await _client.rpc<Map<String, dynamic>>(
      'update_customer_contact',
      params: {
        'p_contact_id': id,
        'p_name': name,
        'p_phone': phone,
        'p_role': role,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return _contact(row);
  }

  Future<void> deleteCustomerContact(String id) async {
    await _client.rpc(
      'delete_customer_contact',
      params: {
        'p_contact_id': id,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
  }

  Future<List<ProductBuyer>> getProductBuyers(String productId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'product_buyers',
      params: {'p_product_id': productId},
    );
    return rows.map((row) => _buyer(row as Map<String, dynamic>)).toList();
  }

  CustomerContact _contact(Map<String, dynamic> row) => CustomerContact(
    id: row['id'] as String,
    customerId: row['customer_id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String?,
    role: row['role'] as String?,
  );

  ProductBuyer _buyer(Map<String, dynamic> row) => ProductBuyer(
    customerId: row['customer_id'] as String?,
    name: row['customer_name'] as String,
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    province: row['province'] as String?,
    gira: row['gira'] as String?,
    isActive: row['is_active'] as bool? ?? true,
    lastPurchaseAt: row['last_purchase_at'] == null
        ? null
        : DateTime.parse(row['last_purchase_at'] as String),
    totalQuantity: (row['total_quantity'] as num?)?.toInt() ?? 0,
    documentsCount: (row['documents_count'] as num?)?.toInt() ?? 0,
    contacts:
        (row['contacts'] as List<dynamic>?)
            ?.map(
              (contact) => CustomerContact(
                id: (contact as Map<String, dynamic>)['id'] as String,
                customerId: row['customer_id'] as String? ?? '',
                name: contact['name'] as String,
                phone: contact['phone'] as String?,
                role: contact['role'] as String?,
              ),
            )
            .toList() ??
        const [],
  );

  Customer _customer(Map<String, dynamic> row) => Customer(
    id: row['id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    address: row['address'] as String?,
    taxId: row['tax_id'] as String?,
    province: row['province'] as String?,
    gira: row['gira'] as String?,
    isActive: row['is_active'] as bool? ?? true,
    creditLimit: (row['credit_limit'] as num?)?.toDouble() ?? 0,
    currentBalance: (row['current_balance'] as num?)?.toDouble() ?? 0,
    createdAt: row['created_at'] == null
        ? null
        : DateTime.parse(row['created_at'] as String),
    updatedAt: row['updated_at'] == null
        ? null
        : DateTime.parse(row['updated_at'] as String),
  );
}
