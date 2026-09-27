import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';
import '../controllers/product_list_controller.dart';

enum ProductView { list, grid }

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _searchController = TextEditingController();
  ProductView _view = ProductView.list;
  bool _onlyLowStock = false;
  bool? _activeStatus = true;

  @override
  void dispose() {
    _searchController.dispose();
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
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productListControllerProvider);

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
              view: _view,
              activeStatus: _activeStatus,
              onlyLowStock: _onlyLowStock,
              onSearch: _applyFilters,
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
                    ? _ProductTable(products: items)
                    : _ProductGrid(products: items),
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
    required this.view,
    required this.activeStatus,
    required this.onlyLowStock,
    required this.onSearch,
    required this.onViewChanged,
    required this.onStatusChanged,
    required this.onLowStockChanged,
  });

  final TextEditingController searchController;
  final ProductView view;
  final bool? activeStatus;
  final bool onlyLowStock;
  final VoidCallback onSearch;
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
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, SKU o descripción',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: onSearch,
                icon: const Icon(Icons.arrow_forward),
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
  const _ProductTable({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Producto')),
            DataColumn(label: Text('Precio'), numeric: true),
            DataColumn(label: Text('Stock'), numeric: true),
            DataColumn(label: Text('MOQ'), numeric: true),
            DataColumn(label: Text('Estado')),
          ],
          rows: [
            for (final product in products)
              DataRow(
                cells: [
                  DataCell(Text(product.sku)),
                  DataCell(Text(product.name)),
                  DataCell(
                    Text(
                      '\$${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
                    ),
                  ),
                  DataCell(Text('${product.currentStock}')),
                  DataCell(Text('${product.minimumOrderQuantity}')),
                  DataCell(_StockBadge(product: product)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 330,
        mainAxisExtent: 190,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(product.sku)),
                    _StockBadge(product: product),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleMedium,
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
                    Text('Stock ${product.currentStock}'),
                    Text(
                      '\$${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
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
