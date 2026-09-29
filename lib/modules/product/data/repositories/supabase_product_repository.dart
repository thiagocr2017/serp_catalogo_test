import '../../api/product_api.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/product_repository.dart';
import '../data_sources/supabase_product_data_source.dart';
import '../mappers/product_mapper.dart';

class SupabaseProductRepository implements ProductRepository, ProductApi {
  const SupabaseProductRepository(this._dataSource);

  final SupabaseProductDataSource _dataSource;

  @override
  Future<List<Product>> getProducts([
    ProductQuery query = const ProductQuery(),
  ]) async {
    final products = await _dataSource.getProducts(query);
    return products.map((product) => product.toDomain()).toList();
  }

  @override
  Future<Product?> getProductById(String id) async {
    return (await _dataSource.getProductById(id))?.toDomain();
  }

  @override
  Future<Product> createProduct(
    Product product, {
    required int initialStock,
  }) async {
    return (await _dataSource.createProduct(
      product.toPersistence(),
      initialStock: initialStock,
    )).toDomain();
  }

  @override
  Future<List<Category>> getCategories() async =>
      (await _dataSource.getCategories())
          .map((item) => item.toDomain())
          .toList();

  @override
  Future<Category> createCategory(String name) async =>
      (await _dataSource.createCategory(name)).toDomain();

  @override
  Future<Category> updateCategory(String id, String name) async =>
      (await _dataSource.updateCategory(id, name)).toDomain();

  @override
  Future<void> deleteCategory({
    required String categoryId,
    String? replacementCategoryId,
  }) => _dataSource.deleteCategory(
    categoryId: categoryId,
    replacementCategoryId: replacementCategoryId,
  );

  @override
  Future<Product> updateProduct(Product product) async {
    return (await _dataSource.updateProduct(
      product.id,
      product.toPersistence(),
    )).toDomain();
  }

  @override
  Future<void> deactivateProduct(String id) =>
      _dataSource.deactivateProduct(id);

  @override
  Future<void> saveCatalogOrder({
    required List<String> productIds,
    required List<String> categoryIds,
  }) => _dataSource.saveCatalogOrder(
    productIds: productIds,
    categoryIds: categoryIds,
  );
}
