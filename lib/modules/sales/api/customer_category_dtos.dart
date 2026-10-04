import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_api.dart';

class CustomerCategoryDto {
  const CustomerCategoryDto({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.isActive = true,
  });

  factory CustomerCategoryDto.fromJson(Map<String, dynamic> json) =>
      CustomerCategoryDto(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        color: json['color'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  final String id;
  final String name;
  final String? description;
  final String? color;
  final bool isActive;
}

final customerCategoriesProvider =
    FutureProvider.autoDispose<List<CustomerCategoryDto>>((ref) async {
  final api = ref.watch(customerApiProvider);
  return api.getCustomerCategories();
});
