import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product_query.dart';
import '../../di/product_providers.dart';
import '../controllers/product_list_controller.dart';

enum ProductView { list, grid }

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _searchController = TextEditingController();
  final _minimumPriceController = TextEditingController();
  final _maximumPriceController = TextEditingController();
  ProductView _view = ProductView.list;
  bool _onlyLowStock = false;
  bool? _activeStatus = true;
  String? _categoryId;

  @override
  void dispose() {
    _searchController.dispose();
    _minimumPriceController.dispose();
    _maximumPriceController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref
        .read(productListControllerProvider.notifier)
        .applyQuery(
          ProductQuery(
            searchTerm: _searchController.text,
            isActive: _activeStatus,
            onlyLowStock: _onlyLowStock,
            categoryId: _categoryId,
            minimumPriceInCents: _toCents(_minimumPriceController.text),
            maximumPriceInCents: _toCents(_maximumPriceController.text),
          ),
        );
  }

  int? _toCents(String value) {
    final amount = double.tryParse(value.replaceAll(',', '.'));
    return amount == null ? null : (amount * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productListControllerProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final selectedIds = ref.watch(selectedProductIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Productos'),
            Text('Catálogo e inventario base', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(productListControllerProvider.notifier).refresh(),
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/products/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          children: [
            _Toolbar(
              searchController: _searchController,
              minimumPriceController: _minimumPriceController,
              maximumPriceController: _maximumPriceController,
              categories: categories,
              categoryId: _categoryId,
              view: _view,
              activeStatus: _activeStatus,
              onlyLowStock: _onlyLowStock,
              onSearch: _applyFilters,
              onCategoryChanged: (categoryId) {
                setState(() => _categoryId = categoryId);
                _applyFilters();
              },
              onViewChanged: (view) => setState(() => _view = view),
              onStatusChanged: (status) {
                setState(() => _activeStatus = status);
                _applyFilters();
              },
              onLowStockChanged: (selected) {
                setState(() => _onlyLowStock = selected);
                _applyFilters();
              },
            ),
            const SizedBox(height: 20),
            if (selectedIds.isNotEmpty) ...[
              Row(
                children: [
                  Text('${selectedIds.length} producto(s) seleccionado(s)'),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => context.go('/catalog-export'),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Exportar seleccionados'),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(selectedProductIdsProvider.notifier).clear(),
                    child: const Text('Limpiar selección'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: products.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text('No fue posible cargar los productos.\n$error'),
                ),
                data: (items) => items.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay productos que coincidan con los filtros.',
                        ),
                      )
                    : _view == ProductView.list
                    ? _ProductTable(
                        products: items,
                        selectedIds: selectedIds,
                        onSelectAll: (selected) => ref
                            .read(selectedProductIdsProvider.notifier)
                            .setMany(
                              items.map((product) => product.id),
                              selected: selected,
                            ),
                        onSelected: (id, selected) => ref
                            .read(selectedProductIdsProvider.notifier)
                            .toggle(id, selected: selected),
                      )
                    : _ProductGrid(
                        products: items,
                        selectedIds: selectedIds,
                        onSelected: (id, selected) => ref
                            .read(selectedProductIdsProvider.notifier)
                            .toggle(id, selected: selected),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.minimumPriceController,
    required this.maximumPriceController,
    required this.categories,
    required this.categoryId,
    required this.view,
    required this.activeStatus,
    required this.onlyLowStock,
    required this.onSearch,
    required this.onCategoryChanged,
    required this.onViewChanged,
    required this.onStatusChanged,
    required this.onLowStockChanged,
  });

  final TextEditingController searchController;
  final TextEditingController minimumPriceController;
  final TextEditingController maximumPriceController;
  final List<Category> categories;
  final String? categoryId;
  final ProductView view;
  final bool? activeStatus;
  final bool onlyLowStock;
  final VoidCallback onSearch;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<ProductView> onViewChanged;
  final ValueChanged<bool?> onStatusChanged;
  final ValueChanged<bool> onLowStockChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            controller: searchController,
            onChanged: (value) {
              if (value.isEmpty) onSearch();
            },
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, SKU o descripción',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: searchController,
                builder: (context, value, _) => IconButton(
                  tooltip: value.text.isEmpty ? 'Buscar' : 'Limpiar búsqueda',
                  onPressed: value.text.isEmpty
                      ? onSearch
                      : () {
                          searchController.clear();
                          onSearch();
                        },
                  icon: Icon(
                    value.text.isEmpty ? Icons.arrow_forward : Icons.close,
                  ),
                ),
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        DropdownButton<bool?>(
          value: activeStatus,
          items: const [
            DropdownMenuItem(value: true, child: Text('Activos')),
            DropdownMenuItem(value: false, child: Text('Inactivos')),
            DropdownMenuItem(value: null, child: Text('Todos')),
          ],
          onChanged: onStatusChanged,
        ),
        DropdownButton<String?>(
          value: categoryId,
          hint: const Text('Categoría'),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Todas las categorías'),
            ),
            for (final category in categories)
              DropdownMenuItem(value: category.id, child: Text(category.name)),
          ],
          onChanged: onCategoryChanged,
        ),
        SizedBox(
          width: 120,
          child: TextField(
            controller: minimumPriceController,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              labelText: 'Precio mín.',
              prefixText: r'$ ',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 120,
          child: TextField(
            controller: maximumPriceController,
            keyboardType: TextInputType.number,
            onSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              labelText: 'Precio máx.',
              prefixText: r'$ ',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        FilterChip(
          selected: onlyLowStock,
          onSelected: onLowStockChanged,
          avatar: const Icon(Icons.warning_amber, size: 18),
          label: const Text('Stock bajo'),
        ),
        SegmentedButton<ProductView>(
          segments: const [
            ButtonSegment(
              value: ProductView.list,
              icon: Icon(Icons.table_rows),
              tooltip: 'Lista',
            ),
            ButtonSegment(
              value: ProductView.grid,
              icon: Icon(Icons.grid_view),
              tooltip: 'Cuadrícula',
            ),
          ],
          selected: {view},
          onSelectionChanged: (selection) => onViewChanged(selection.first),
          showSelectedIcon: false,
        ),
      ],
    );
  }
}

class _ProductTable extends StatelessWidget {
  const _ProductTable({
    required this.products,
    required this.selectedIds,
    required this.onSelected,
    required this.onSelectAll,
  });
  final List<Product> products;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onSelected;
  final ValueChanged<bool> onSelectAll;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: [
            DataColumn(
              label: Checkbox(
                value:
                    products.isNotEmpty &&
                    products.every(
                      (product) => selectedIds.contains(product.id),
                    ),
                onChanged: (selected) => onSelectAll(selected ?? false),
              ),
              tooltip: 'Seleccionar todos los productos visibles',
            ),
            const DataColumn(label: Text('Imagen')),
            const DataColumn(label: Text('SKU')),
            const DataColumn(label: Text('Producto')),
            const DataColumn(label: Text('Precio'), numeric: true),
            const DataColumn(label: Text('Stock'), numeric: true),
            const DataColumn(label: Text('Venta mín.'), numeric: true),
            const DataColumn(label: Text('Estado')),
          ],
          rows: [
            for (final product in products)
              DataRow(
                selected: selectedIds.contains(product.id),
                cells: [
                  DataCell(
                    Checkbox(
                      value: selectedIds.contains(product.id),
                      onChanged: (selected) =>
                          onSelected(product.id, selected ?? false),
                    ),
                  ),
                  DataCell(
                    _ProductThumbnail(product: product, size: 52),
                    onTap: () => context.go('/products/${product.id}'),
                  ),
                  DataCell(
                    Text(product.sku),
                    onTap: () => context.go('/products/${product.id}'),
                  ),
                  DataCell(
                    Text(product.name),
                    onTap: () => context.go('/products/${product.id}'),
                  ),
                  DataCell(
                    Text(
                      '\$${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
                    ),
                    onTap: () => context.go('/products/${product.id}'),
                  ),
                  DataCell(
                    Text('${product.currentStock}'),
                    onTap: () => context.go('/products/${product.id}'),
                  ),
                  DataCell(
                    Text('${product.minimumSaleQuantity}'),
                    onTap: () => context.go('/products/${product.id}'),
                  ),
                  DataCell(
                    _StockBadge(product: product),
                    onTap: () => context.go('/products/${product.id}'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({
    required this.products,
    required this.selectedIds,
    required this.onSelected,
  });
  final List<Product> products;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisExtent: 390,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go('/products/${product.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 185,
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: _ProductThumbnail(product: product, size: 160),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: Checkbox(
                          value: selectedIds.contains(product.id),
                          onChanged: (value) =>
                              onSelected(product.id, value ?? false),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.sku,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            _StockBadge(product: product),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Venta mín. ${product.minimumSaleQuantity}'),
                            Text(
                              '\$${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.product, required this.size});
  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(size * .22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: product.imageUrl == null
        ? Icon(Icons.inventory_2_outlined, size: size * .45)
        : Image.network(
            product.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Icon(Icons.broken_image_outlined, size: size * .45),
          ),
  );
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final (label, color) = product.isOutOfStock
        ? ('Agotado', Colors.red)
        : product.requiresRestock
        ? ('Stock bajo', Colors.orange)
        : ('Disponible', Colors.green);
    return Chip(
      label: Text(label),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}
