import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/product_query.dart';
import '../models/product_model.dart';

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

  Future<ProductModel> createProduct(Map<String, dynamic> values) async {
    final row = await _client.from('products').insert(values).select().single();
    return ProductModel(row);
  }

  Future<ProductModel> updateProduct(
    String id,
    Map<String, dynamic> values,
  ) async {
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
        })
        .eq('id', id);
  }
}
