import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/navigation/unsaved_changes_guard.dart';
import '../../di/product_providers.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';
import '../controllers/product_list_controller.dart';

class CategoryPage extends ConsumerStatefulWidget {
  const CategoryPage({super.key});

  @override
  ConsumerState<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends ConsumerState<CategoryPage> {
  List<Product> _products = const [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await ref.read(getProductsProvider)(const ProductQuery());
    if (mounted) {
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editCategory(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No fue posible cargar: $error')),
        data: (items) => items.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category_outlined, size: 56),
                    SizedBox(height: 12),
                    Text('No existen categorías.'),
                    SizedBox(height: 4),
                    Text('Crea la primera categoría para registrar productos.'),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, index) {
                  final category = items[index];
                  final productCount = _products
                      .where((product) => product.categoryId == category.id)
                      .length;
                  return ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(category.name),
                    subtitle: Text(
                      _loadingProducts
                          ? 'Contando productos…'
                          : '$productCount producto(s)',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Editar categoría',
                          onPressed: () => _editCategory(category),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Eliminar categoría',
                          onPressed: items.length <= 1
                              ? null
                              : () => _deleteCategory(
                                  category,
                                  categories: items,
                                  productCount: productCount,
                                ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _editCategory([Category? existing]) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    String? errorText;
    var dirty = false;
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void markDirty() {
            if (dirty) return;
            setDialogState(() => dirty = true);
          }

          Future<void> cancel() async {
            final navigator = Navigator.of(context);
            final discard = await UnsavedChangesGuard.instance.confirmDiscard(
              context,
              hasUnsavedChanges: dirty,
            );
            if (discard && context.mounted) navigator.pop();
          }

          void submit() {
            final value = controller.text.trim();
            if (value.isEmpty) {
              setDialogState(() {
                errorText = 'Escriba el nombre de la categoría.';
              });
              return;
            }
            Navigator.pop(context, value);
          }

          return PopScope(
            canPop: !dirty,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await cancel();
            },
            child: AlertDialog(
              title: Text(
                existing == null ? 'Nueva categoría' : 'Editar categoría',
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  markDirty();
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(onPressed: cancel, child: const Text('Cancelar')),
                FilledButton(onPressed: submit, child: const Text('Guardar')),
              ],
            ),
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (name == null || name.isEmpty) return;
    final repository = ref.read(productRepositoryProvider);
    if (existing == null) {
      await repository.createCategory(name);
    } else {
      await repository.updateCategory(existing.id, name);
    }
    ref.invalidate(categoriesProvider);
    await ref.read(productListControllerProvider.notifier).refresh();
  }

  Future<void> _deleteCategory(
    Category category, {
    required List<Category> categories,
    required int productCount,
  }) async {
    final destinations = categories
        .where((item) => item.id != category.id)
        .toList();
    String? destinationId = productCount > 0 ? destinations.first.id : null;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Eliminar “${category.name}”'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (productCount == 0)
                const Text('La categoría está vacía y puede eliminarse.')
              else ...[
                Text(
                  'Esta categoría contiene $productCount producto(s). No se eliminarán: selecciona la categoría a la que deben moverse.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: destinationId,
                  decoration: const InputDecoration(
                    labelText: 'Mover productos a',
                    border: OutlineInputBorder(),
                  ),
                  items: destinations
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => destinationId = value),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: productCount > 0 && destinationId == null
                  ? null
                  : () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete_outline),
              label: Text(productCount > 0 ? 'Mover y eliminar' : 'Eliminar'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    await ref
        .read(productRepositoryProvider)
        .deleteCategory(
          categoryId: category.id,
          replacementCategoryId: destinationId,
        );
    ref.invalidate(categoriesProvider);
    await ref.read(productListControllerProvider.notifier).refresh();
    await _loadProducts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            productCount > 0
                ? 'Productos movidos y categoría eliminada.'
                : 'Categoría eliminada.',
          ),
        ),
      );
    }
  }
}
