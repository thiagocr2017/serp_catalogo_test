import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/device_identity.dart';

import '../../domain/entities/product_query.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';

class SupabaseProductDataSource {
  const SupabaseProductDataSource(this._client, this._device);

  final SupabaseClient _client;
  final DeviceIdentity _device;

  Future<List<ProductModel>> getProducts(ProductQuery query) async {
    final rows = await _client
        .from('product_catalog')
        .select()
        .order('catalog_sort_order')
        .order('name');
    final products = rows.map(ProductModel.new).toList();

    return products.where((product) {
      final searchTerm = query.searchTerm?.trim().toLowerCase();
      final matchesSearch =
          searchTerm == null ||
          searchTerm.isEmpty ||
          product.name.toLowerCase().contains(searchTerm) ||
          product.sku.toLowerCase().contains(searchTerm) ||
          product.description.toLowerCase().contains(searchTerm);
      final matchesCategory =
          query.categoryId == null || product.categoryId == query.categoryId;
      final matchesStatus =
          query.isActive == null || product.isActive == query.isActive;
      final matchesStock =
          !query.onlyLowStock || product.currentStock <= product.reorderPoint;
      final matchesMinimumPrice =
          query.minimumPriceInCents == null ||
          product.unitPriceInCents >= query.minimumPriceInCents!;
      final matchesMaximumPrice =
          query.maximumPriceInCents == null ||
          product.unitPriceInCents <= query.maximumPriceInCents!;

      return matchesSearch &&
          matchesCategory &&
          matchesStatus &&
          matchesStock &&
          matchesMinimumPrice &&
          matchesMaximumPrice;
    }).toList();
  }

  Future<ProductModel?> getProductById(String id) async {
    final row = await _client
        .from('product_catalog')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ProductModel(row);
  }

  Future<ProductModel> createProduct(
    Map<String, dynamic> values, {
    required int initialStock,
  }) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_product_with_initial_stock',
      params: {
        'p_product': values,
        'p_initial_stock': initialStock,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    final updated = await _client
        .from('products')
        .update({
          'image_position_x': values['image_position_x'],
          'image_position_y': values['image_position_y'],
          'image_scale': values['image_scale'],
          'catalog_sort_order': values['catalog_sort_order'],
          'packaging_presentation_id': values['packaging_presentation_id'],
        })
        .eq('id', row['id'] as String)
        .select()
        .single();
    return ProductModel(updated);
  }

  Future<List<CategoryModel>> getCategories() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('catalog_sort_order')
        .order('name');
    return rows.map(CategoryModel.new).toList();
  }

  Future<CategoryModel> createCategory(String name) async {
    final row = await _client
        .from('categories')
        .insert({
          'name': name.trim(),
          'created_by': _device.actorName,
          'created_device_name': _device.name,
          'created_device_identifier': _device.identifier,
        })
        .select()
        .single();
    return CategoryModel(row);
  }

  Future<ProductModel> updateProduct(
    String id,
    Map<String, dynamic> values,
  ) async {
    if (values['is_active'] == true) {
      values.addAll({'deleted_at': null, 'deleted_by': null});
    }
    values.addAll({
      'updated_by': _device.actorName,
      'updated_device_name': _device.name,
      'updated_device_identifier': _device.identifier,
    });
    final row = await _client
        .from('products')
        .update(values)
        .eq('id', id)
        .select()
        .single();
    return ProductModel(row);
  }

  Future<void> deactivateProduct(String id) async {
    await _client
        .from('products')
        .update({
          'is_active': false,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'deleted_by': _device.actorName,
          'updated_by': _device.actorName,
          'updated_device_name': _device.name,
          'updated_device_identifier': _device.identifier,
        })
        .eq('id', id);
  }

  Future<void> saveCatalogOrder({
    required List<String> productIds,
    required List<String> categoryIds,
  }) => _client.rpc<void>(
    'save_catalog_order',
    params: {
      'p_product_ids': productIds,
      'p_category_ids': categoryIds,
      'p_actor_name': _device.actorName,
      'p_device_name': _device.name,
      'p_device_identifier': _device.identifier,
    },
  );
}
