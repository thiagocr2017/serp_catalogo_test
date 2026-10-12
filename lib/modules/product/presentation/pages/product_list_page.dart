import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product_query.dart';
import '../../di/product_providers.dart';
import '../controllers/product_list_controller.dart';
import '../../../../shared/utilities/search_query.dart';
import '../widgets/product_status_badge.dart';

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
  Timer? _searchDebounce;
  final _changingProductStatusIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _minimumPriceController.dispose();
    _maximumPriceController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    _searchDebounce?.cancel();
    ref
        .read(productListControllerProvider.notifier)
        .applyQuery(
          ProductQuery(
            searchTerm: effectiveSearchQuery(_searchController.text),
            isActive: _activeStatus,
            onlyLowStock: _onlyLowStock,
            categoryId: _categoryId,
            minimumPriceInCents: _toCents(_minimumPriceController.text),
            maximumPriceInCents: _toCents(_maximumPriceController.text),
          ),
        );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (effectiveSearchQuery(value).isEmpty) {
      _applyFilters();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 150), _applyFilters);
  }

  int? _toCents(String value) {
    final amount = double.tryParse(value.replaceAll(',', '.'));
    return amount == null ? null : (amount * 100).round();
  }

  Future<void> _changeProductStatus(Product product) async {
    final activating = !product.isActive;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(activating ? 'Activar producto' : 'Desactivar producto'),
        content: Text(
          activating
              ? '${product.name} volverá a aparecer entre los productos activos.'
              : '${product.name} dejará de aparecer entre los productos activos, pero conservará su historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(activating ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _changingProductStatusIds.add(product.id));
    try {
      if (activating) {
        await ref.read(saveProductProvider).update(_withActiveStatus(product));
      } else {
        await ref.read(deactivateProductProvider)(product.id);
      }
      await ref.read(productListControllerProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activating ? 'Producto activado.' : 'Producto desactivado.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo ${activating ? 'activar' : 'desactivar'} el producto: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _changingProductStatusIds.remove(product.id));
      }
    }
  }

  Product _withActiveStatus(Product product) => Product(
    id: product.id,
    sku: product.sku,
    barcode: product.barcode,
    name: product.name,
    description: product.description,
    categoryId: product.categoryId,
    unitPriceInCents: product.unitPriceInCents,
    packagePriceInCents: product.packagePriceInCents,
    minimumOrderQuantity: product.minimumOrderQuantity,
    minimumSaleQuantity: product.minimumSaleQuantity,
    unitsPerPresentation: product.unitsPerPresentation,
    packagingPresentationId: product.packagingPresentationId,
    packagingPresentationName: product.packagingPresentationName,
    cbmPerMoq: product.cbmPerMoq,
    factoryCostInCents: product.factoryCostInCents,
    extraCostsInCents: product.extraCostsInCents,
    imageUrl: product.imageUrl,
    imagePositionX: product.imagePositionX,
    imagePositionY: product.imagePositionY,
    imageScale: product.imageScale,
    catalogSortOrder: product.catalogSortOrder,
    currentStock: product.currentStock,
    reorderPoint: product.reorderPoint,
    promotionPriceInCents: product.promotionPriceInCents,
    promotionText: product.promotionText,
    promotionType: product.promotionType,
    bulkPromotionId: product.bulkPromotionId,
    bulkPromotionName: product.bulkPromotionName,
    bulkPromotionConditions: product.bulkPromotionConditions,
    bulkProductConditions: product.bulkProductConditions,
    isActive: true,
    createdAt: product.createdAt,
    updatedAt: DateTime.now().toUtc(),
    deletedAt: product.deletedAt,
  );

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
              onSearchChanged: _onSearchChanged,
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
              child: Column(
                children: [
                  if (products.isLoading && products.hasValue)
                    Semantics(
                      label: 'Buscando productos',
                      liveRegion: true,
                      child: const LinearProgressIndicator(minHeight: 2),
                    ),
                  Expanded(
                    child: products.when(
                      skipLoadingOnReload: true,
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) => Center(
                        child: Text(
                          'No fue posible cargar los productos.\n$error',
                        ),
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
                              categories: categories,
                              selectedIds: selectedIds,
                              changingProductStatusIds:
                                  _changingProductStatusIds,
                              onStatusChange: _changeProductStatus,
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
                              changingProductStatusIds:
                                  _changingProductStatusIds,
                              onStatusChange: _changeProductStatus,
                              onSelected: (id, selected) => ref
                                  .read(selectedProductIdsProvider.notifier)
                                  .toggle(id, selected: selected),
                            ),
                    ),
                  ),
                ],
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
    required this.onSearchChanged,
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
  final ValueChanged<String> onSearchChanged;
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
            onChanged: onSearchChanged,
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
    required this.categories,
    required this.selectedIds,
    required this.changingProductStatusIds,
    required this.onStatusChange,
    required this.onSelected,
    required this.onSelectAll,
  });
  final List<Product> products;
  final List<Category> categories;
  final Set<String> selectedIds;
  final Set<String> changingProductStatusIds;
  final ValueChanged<Product> onStatusChange;
  final void Function(String id, bool selected) onSelected;
  final ValueChanged<bool> onSelectAll;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 88),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columnSpacing: 18,
          horizontalMargin: 8,
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
            const DataColumn(label: Text('Categoría')),
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
                    _ProductThumbnail(
                      product: product,
                      size: 44,
                      verticalPadding: 5,
                    ),
                    onTap: () => context.go('/products/${product.id}'),
                  ),
                  DataCell(
                    Text(product.sku),
                    onTap: () => context.go('/products/${product.id}'),
                  ),
                  DataCell(
                    SizedBox(
                      width: 140,
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                    SizedBox(
                      width: 90,
                      child: Text(
                        categories
                                .where(
                                  (category) =>
                                      category.id == product.categoryId,
                                )
                                .firstOrNull
                                ?.name ??
                            'Sin categoría',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onTap: () => context.go('/products/${product.id}'),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ProductActionsMenu(
                          product: product,
                          isChanging: changingProductStatusIds.contains(
                            product.id,
                          ),
                          onStatusChange: onStatusChange,
                        ),
                        Flexible(
                          child: ProductStatusBadge(
                            product: product,
                            showStockStatus: false,
                          ),
                        ),
                      ],
                    ),
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
    required this.changingProductStatusIds,
    required this.onStatusChange,
    required this.onSelected,
  });
  final List<Product> products;
  final Set<String> selectedIds;
  final Set<String> changingProductStatusIds;
  final ValueChanged<Product> onStatusChange;
  final void Function(String id, bool selected) onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 88),
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
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: _ProductActionsMenu(
                          product: product,
                          isChanging: changingProductStatusIds.contains(
                            product.id,
                          ),
                          onStatusChange: onStatusChange,
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            Flexible(
                              child: ProductStatusBadge(product: product),
                            ),
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
                            Flexible(
                              child: Text(
                                'Venta mín. ${product.minimumSaleQuantity}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '\$${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
  const _ProductThumbnail({
    required this.product,
    required this.size,
    this.verticalPadding = 0,
  });
  final Product product;
  final double size;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: verticalPadding),
    child: Container(
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
          : FractionalTranslation(
              translation: Offset(
                (product.imagePositionX - .5) * .9,
                (product.imagePositionY - .5) * .9,
              ),
              child: Transform.scale(
                scale: product.imageScale,
                child: _LocalImageThumbnail(
                  sku: product.sku,
                  url: product.imageUrl!,
                ),
              ),
            ),
    ),
  );
}

class _ProductActionsMenu extends StatelessWidget {
  const _ProductActionsMenu({
    required this.product,
    required this.isChanging,
    required this.onStatusChange,
  });

  final Product product;
  final bool isChanging;
  final ValueChanged<Product> onStatusChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Acciones del producto',
      enabled: !isChanging,
      icon: isChanging
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.more_horiz, color: scheme.onSurfaceVariant),
      onSelected: (action) {
        if (action == 'edit') {
          context.go('/products/${product.id}/edit?returnTo=list');
        } else {
          onStatusChange(product);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: _ProductMenuAction(icon: Icons.edit_outlined, label: 'Editar'),
        ),
        PopupMenuItem(
          value: 'status',
          child: _ProductMenuAction(
            icon: product.isActive
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            label: product.isActive ? 'Desactivar' : 'Activar',
          ),
        ),
      ],
    );
  }
}

class _ProductMenuAction extends StatelessWidget {
  const _ProductMenuAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 18), const SizedBox(width: 12), Text(label)],
  );
}

class _LocalImageThumbnail extends ConsumerStatefulWidget {
  const _LocalImageThumbnail({required this.sku, required this.url});
  final String sku;
  final String url;

  @override
  ConsumerState<_LocalImageThumbnail> createState() =>
      _LocalImageThumbnailState();
}

class _LocalImageThumbnailState extends ConsumerState<_LocalImageThumbnail> {
  File? _file;
  bool _failed = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _LocalImageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sku != widget.sku || oldWidget.url != widget.url) {
      _file = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final service = ref.read(productImageServiceProvider);
      final file = await service.getLocalThumbnail(widget.sku, widget.url);
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _file = file;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) {
      if (_failed) return const Icon(Icons.broken_image_outlined);
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
    );
  }
}
