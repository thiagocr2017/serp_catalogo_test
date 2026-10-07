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
    var queryBuilder = _client
        .from('product_catalog')
        .select();

    final searchTerm = query.searchTerm?.trim().toLowerCase();
    if (searchTerm != null && searchTerm.isNotEmpty) {
      queryBuilder = queryBuilder.or('name.ilike.%$searchTerm%,sku.ilike.%$searchTerm%,description.ilike.%$searchTerm%');
    }

    if (query.categoryId != null) {
      queryBuilder = queryBuilder.eq('category_id', query.categoryId as Object);
    }
    
    if (query.isActive != null) {
      queryBuilder = queryBuilder.eq('is_active', query.isActive as Object);
    }

    if (query.onlyLowStock) {
      // Handled in dart fallback
    }

    if (query.minimumPriceInCents != null) {
      queryBuilder = queryBuilder.gte('unit_price', query.minimumPriceInCents! / 100);
    }

    if (query.maximumPriceInCents != null) {
      queryBuilder = queryBuilder.lte('unit_price', query.maximumPriceInCents! / 100);
    }

    final rows = await queryBuilder
        .order('category_sort_order')
        .order('catalog_sort_order')
        .order('name');
        
    final products = rows.map(ProductModel.new).toList();
    
    // Fallback for column comparison not supported directly by PostgREST
    return products.where((product) {
      final matchesStock = !query.onlyLowStock || product.currentStock <= product.reorderPoint;
      return matchesStock;
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
    return ProductModel(row);
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
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_category',
      params: {
        'p_name': name,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return CategoryModel(row);
  }

  Future<CategoryModel> updateCategory(String id, String name) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'update_category',
      params: {
        'p_category_id': id,
        'p_name': name,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return CategoryModel(row);
  }

  Future<void> deleteCategory({
    required String categoryId,
    String? replacementCategoryId,
  }) => _client.rpc<void>(
    'delete_category_and_reassign_products',
    params: {
      'p_category_id': categoryId,
      'p_replacement_category_id': replacementCategoryId,
      'p_actor_name': _device.actorName,
      'p_device_name': _device.name,
      'p_device_identifier': _device.identifier,
    },
  );

  Future<ProductModel> updateProduct(
    String id,
    Map<String, dynamic> values,
  ) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'update_product',
      params: {
        'p_product_id': id,
        'p_product': values,
        'p_actor_name': _device.actorName,
        'p_device_name': _device.name,
        'p_device_identifier': _device.identifier,
      },
    );
    return ProductModel(row);
  }

  Future<void> deactivateProduct(String id) => _client.rpc<void>(
    'deactivate_product',
    params: {
      'p_product_id': id,
      'p_actor_name': _device.actorName,
      'p_device_name': _device.name,
      'p_device_identifier': _device.identifier,
    },
  );

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
