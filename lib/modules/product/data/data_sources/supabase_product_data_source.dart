import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/product_query.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';

class SupabaseProductDataSource {
  const SupabaseProductDataSource(this._client);

  final SupabaseClient _client;

  Future<List<ProductModel>> getProducts(ProductQuery query) async {
    final rows = await _client.from('products').select().order('name');
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
        .from('products')
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
        'p_actor_name': 'Desktop local',
        'p_device_name': 'SERP Desktop',
        'p_device_identifier': 'local-device',
      },
    );
    return ProductModel(row);
  }

  Future<List<CategoryModel>> getCategories() async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('name');
    return rows.map(CategoryModel.new).toList();
  }

  Future<CategoryModel> createCategory(String name) async {
    final row = await _client
        .from('categories')
        .insert({
          'name': name.trim(),
          'created_by': 'Desktop local',
          'created_device_name': 'SERP Desktop',
          'created_device_identifier': 'local-device',
        })
        .select()
        .single();
    return CategoryModel(row);
  }

  Future<ProductModel> updateProduct(
    String id,
    Map<String, dynamic> values,
  ) async {
    values.addAll({
      'updated_by': 'Desktop local',
      'updated_device_name': 'SERP Desktop',
      'updated_device_identifier': 'local-device',
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
          'deleted_by': 'Desktop local',
          'updated_by': 'Desktop local',
          'updated_device_name': 'SERP Desktop',
          'updated_device_identifier': 'local-device',
        })
        .eq('id', id);
  }
}
