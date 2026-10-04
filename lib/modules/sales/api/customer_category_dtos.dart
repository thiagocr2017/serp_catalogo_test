import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_api.dart';

export '../../configuration/configuration_module.dart'
    show CustomerCategoryDto;

final customerCategoriesProvider =
    FutureProvider.autoDispose<List<CustomerCategoryDto>>((ref) async {
  final api = ref.watch(customerApiProvider);
  return api.getCustomerCategories();
});
