import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/device_identity.dart';

import '../../domain/entities/bulk_promotion.dart';
import '../../domain/repositories/promotion_repository.dart';

class SupabasePromotionRepository implements PromotionRepository {
  const SupabasePromotionRepository(this._client, this._device);
  final SupabaseClient _client;
  final DeviceIdentity _device;

  @override
  Future<List<BulkPromotion>> getPromotions() async {
    final rows = await _client
        .from('bulk_promotions')
        .select()
        .order('created_at', ascending: false);
    final productLinks = await _client
        .from('bulk_promotion_products')
        .select('promotion_id, product_id, conditions_text');
    final categoryLinks = await _client
        .from('bulk_promotion_categories')
        .select('promotion_id, category_id');
    return rows.map((row) {
      final id = row['id'] as String;
      final linkedProducts = productLinks.where(
        (link) => link['promotion_id'] == id,
      );
      return _map(
        row,
        productIds: linkedProducts
            .map((link) => link['product_id'] as String)
            .toSet(),
        categoryIds: categoryLinks
            .where((link) => link['promotion_id'] == id)
            .map((link) => link['category_id'] as String)
            .toSet(),
        productConditions: {
          for (final link in linkedProducts)
            if ((link['conditions_text'] as String).trim().isNotEmpty)
              link['product_id'] as String: link['conditions_text'] as String,
        },
      );
    }).toList();
  }

  @override
  Future<BulkPromotion> createPromotion(
    BulkPromotion promotion, {
    required Set<String> productIds,
    Set<String> categoryIds = const {},
    Map<String, String> productConditions = const {},
  }) async {
    final row = await _client
        .from('bulk_promotions')
        .insert({
          'id': promotion.id,
          'name': promotion.name,
          'discount_percentage': promotion.discountPercentage,
          'conditions_text': promotion.conditionsText,
          'badge_image_url': promotion.badgeImageUrl,
          'start_date': promotion.startDate?.toUtc().toIso8601String(),
          'end_date': promotion.endDate.toUtc().toIso8601String(),
          'applies_to_all_products': promotion.appliesToAllProducts,
          'is_active': promotion.isActive,
          'created_by': _device.actorName,
          'created_device_name': _device.name,
          'created_device_identifier': _device.identifier,
        })
        .select()
        .single();
    await _saveTargets(
      promotion,
      productIds: productIds,
      categoryIds: categoryIds,
      productConditions: productConditions,
    );
    return _map(row);
  }

  @override
  Future<BulkPromotion> updatePromotion(
    BulkPromotion promotion, {
    required Set<String> productIds,
    Set<String> categoryIds = const {},
    Map<String, String> productConditions = const {},
  }) async {
    final row = await _client
        .from('bulk_promotions')
        .update({
          'name': promotion.name,
          'discount_percentage': promotion.discountPercentage,
          'conditions_text': promotion.conditionsText,
          'badge_image_url': promotion.badgeImageUrl,
          'start_date': promotion.startDate?.toUtc().toIso8601String(),
          'end_date': promotion.endDate.toUtc().toIso8601String(),
          'applies_to_all_products': promotion.appliesToAllProducts,
          'is_active': promotion.isActive,
          'updated_by': _device.actorName,
          'updated_device_name': _device.name,
          'updated_device_identifier': _device.identifier,
        })
        .eq('id', promotion.id)
        .select()
        .single();
    await _client
        .from('bulk_promotion_products')
        .delete()
        .eq('promotion_id', promotion.id);
    await _client
        .from('bulk_promotion_categories')
        .delete()
        .eq('promotion_id', promotion.id);
    await _saveTargets(
      promotion,
      productIds: productIds,
      categoryIds: categoryIds,
      productConditions: productConditions,
    );
    return _map(
      row,
      productIds: productIds,
      categoryIds: categoryIds,
      productConditions: productConditions,
    );
  }

  Future<void> _saveTargets(
    BulkPromotion promotion, {
    required Set<String> productIds,
    required Set<String> categoryIds,
    required Map<String, String> productConditions,
  }) async {
    final linkedProductIds = {
      if (!promotion.appliesToAllProducts && categoryIds.isEmpty) ...productIds,
      ...productConditions.keys,
    };
    if (linkedProductIds.isNotEmpty) {
      await _client.from('bulk_promotion_products').insert([
        for (final id in linkedProductIds)
          {
            'promotion_id': promotion.id,
            'product_id': id,
            'conditions_text': productConditions[id]?.trim() ?? '',
          },
      ]);
    }
    if (categoryIds.isNotEmpty) {
      await _client.from('bulk_promotion_categories').insert([
        for (final id in categoryIds)
          {'promotion_id': promotion.id, 'category_id': id},
      ]);
    }
  }

  @override
  Future<void> setActive(String id, {required bool isActive}) => _client
      .from('bulk_promotions')
      .update({
        'is_active': isActive,
        'updated_by': _device.actorName,
        'updated_device_name': _device.name,
        'updated_device_identifier': _device.identifier,
      })
      .eq('id', id);

  @override
  Future<void> setProductCondition({
    required String promotionId,
    required String productId,
    required String conditionsText,
  }) async {
    await _client.from('bulk_promotion_products').upsert({
      'promotion_id': promotionId,
      'product_id': productId,
      'conditions_text': conditionsText.trim(),
    });
  }

  BulkPromotion _map(
    Map<String, dynamic> row, {
    Set<String> productIds = const {},
    Set<String> categoryIds = const {},
    Map<String, String> productConditions = const {},
  }) => BulkPromotion(
    id: row['id'] as String,
    name: row['name'] as String,
    discountPercentage: (row['discount_percentage'] as num).toDouble(),
    conditionsText: row['conditions_text'] as String,
    badgeImageUrl: row['badge_image_url'] as String?,
    startDate: row['start_date'] == null
        ? null
        : DateTime.parse(row['start_date'] as String),
    endDate: DateTime.parse(row['end_date'] as String),
    appliesToAllProducts: row['applies_to_all_products'] as bool,
    isActive: row['is_active'] as bool,
    productIds: productIds,
    categoryIds: categoryIds,
    productConditions: productConditions,
  );
}
