import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/bulk_promotion.dart';
import '../domain/repositories/promotion_repository.dart';

final promotionRepositoryProvider = Provider<PromotionRepository>(
  (ref) => throw StateError('PromotionRepository must be overridden.'),
);
final promotionsProvider = FutureProvider<List<BulkPromotion>>(
  (ref) => ref.watch(promotionRepositoryProvider).getPromotions(),
);
