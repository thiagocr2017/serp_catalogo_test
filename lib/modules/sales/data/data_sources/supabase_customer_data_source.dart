import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/device_identity.dart';
import '../../domain/entities/customer.dart';

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
  }) async {
    final row = await _client
        .from('customers')
        .update({
          'name': name,
          'phone': phone,
          'email': email,
          'address': address,
          'tax_id': taxId,
          'credit_limit': creditLimit,
          'updated_by': _device.actorName,
          'updated_device_name': _device.name,
          'updated_device_identifier': _device.identifier,
        })
        .eq('id', id)
        .select()
        .single();
    return _customer(row);
  }

  Future<void> deactivateCustomer(String id) async {
    await _client
        .from('customers')
        .update({'is_active': false})
        .eq('id', id);
  }

  Customer _customer(Map<String, dynamic> row) => Customer(
    id: row['id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    address: row['address'] as String?,
    taxId: row['tax_id'] as String?,
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
