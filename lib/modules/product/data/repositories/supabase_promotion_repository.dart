import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/device_identity.dart';

import '../../domain/entities/bulk_promotion.dart';
import '../../domain/repositories/promotion_repository.dart';

class SupabasePromotionRepository implements PromotionRepository {
  const SupabasePromotionRepository(this._client, this._device);
  final SupabaseClient _client;
  final DeviceIdentity _device;

  @override
  Future<List<BulkPromotion>> getPromotions() async =>
      (await _client
              .from('bulk_promotions')
              .select()
              .order('created_at', ascending: false))
          .map(_map)
          .toList();

  @override
  Future<BulkPromotion> createPromotion(
    BulkPromotion promotion, {
    required Set<String> productIds,
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
    final linkedProductIds = {
      if (!promotion.appliesToAllProducts) ...productIds,
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
    return _map(row);
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

  BulkPromotion _map(Map<String, dynamic> row) => BulkPromotion(
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
  );
}
