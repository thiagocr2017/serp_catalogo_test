import '../../domain/entities/category.dart';

class CategoryModel {
  const CategoryModel(this.data);
  final Map<String, dynamic> data;

  Category toDomain() => Category(
    id: data['id'] as String,
    name: data['name'] as String,
    isActive: data['is_active'] as bool,
  );
}
