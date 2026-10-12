import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/navigation/unsaved_changes_guard.dart';
import '../../../../shared/utilities/search_query.dart';
import '../../di/product_providers.dart';
import '../../di/promotion_providers.dart';
import '../../domain/entities/bulk_promotion.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';

class PromotionFormPage extends ConsumerStatefulWidget {
  const PromotionFormPage({super.key, this.id});
  final String? id;

  @override
  ConsumerState<PromotionFormPage> createState() => _PromotionFormPageState();
}

class _PromotionFormPageState extends ConsumerState<PromotionFormPage> {
  final _name = TextEditingController();
  final _discount = TextEditingController();
  final _conditions = TextEditingController();
  final _startDate = TextEditingController();
  final _endDate = TextEditingController();
  final _productSearch = TextEditingController();
  final _selectedProducts = <String>{};
  final _selectedCategories = <String>{};
  final _productConditionControllers = <String, TextEditingController>{};

  bool _appliesToAll = true;
  bool _isActive = true;
  bool _saving = false;
  bool _dirty = false;
  bool _confirmingExit = false;
  BulkPromotion? _existing;
  List<Product>? _allProducts;
  List<Category>? _allCategories;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await ref.read(getProductsProvider)(
        const ProductQuery(isActive: true),
      );
      final categories = await ref.read(categoriesProvider.future);
      BulkPromotion? existing;
      if (widget.id != null) {
        final promotions = await ref.read(promotionsProvider.future);
        existing = promotions.firstWhere((p) => p.id == widget.id);
      }

      if (existing != null) {
        _name.text = existing.name;
        _discount.text = existing.discountPercentage.toStringAsFixed(1);
        _conditions.text = existing.conditionsText;
        _appliesToAll = existing.appliesToAllProducts;
        _isActive = existing.isActive;
        _selectedProducts.addAll(existing.productIds);
        _selectedCategories.addAll(existing.categoryIds);
        for (final entry in existing.productConditions.entries) {
          _productConditionControllers[entry.key] = TextEditingController(
            text: entry.value,
          );
        }
        _startDate.text =
            existing.startDate?.toIso8601String().split('T').first ?? '';
        _endDate.text = existing.endDate.toIso8601String().split('T').first;
      }

      if (mounted) {
        setState(() {
          _allProducts = products;
          _allCategories = categories;
          _existing = existing;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la promoción: $error')),
      );
      context.pop();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _discount.dispose();
    _conditions.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _productSearch.dispose();
    for (final controller in _productConditionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _confirmDiscard() async {
    if (_confirmingExit || _saving) return;
    _confirmingExit = true;
    final discard = await UnsavedChangesGuard.instance.confirmDiscard(
      context,
      hasUnsavedChanges: _dirty,
    );
    _confirmingExit = false;
    if (discard && mounted) {
      setState(() => _dirty = false);
      context.pop();
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final discount = double.tryParse(_discount.text.replaceAll(',', '.'));
    final startDate = _optionalDate(_startDate.text);
    final endDate = _optionalDate(_endDate.text);

    if (name.isEmpty || discount == null || discount <= 0 || discount >= 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Indica un nombre y un descuento mayor que 0 y menor que 100.',
          ),
        ),
      );
      return;
    }
    if ((_startDate.text.trim().isNotEmpty && startDate == null) ||
        (_endDate.text.trim().isNotEmpty && endDate == null) ||
        (startDate != null && endDate != null && startDate.isAfter(endDate))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Revisa las fechas: usa AAAA-MM-DD y un inicio anterior al fin.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = ref.read(promotionRepositoryProvider);
      final productConditions = {
        for (final productId in _selectedProducts)
          productId: _productConditionControllers[productId]?.text.trim() ?? '',
      };
      final promotion = BulkPromotion(
        id: _existing?.id ?? '',
        name: name,
        discountPercentage: discount,
        conditionsText: _conditions.text.trim(),
        startDate: startDate,
        endDate: endDate ?? DateTime.now().add(const Duration(days: 365)),
        appliesToAllProducts: _appliesToAll,
        isActive: _isActive,
        productIds: _selectedProducts,
        categoryIds: _selectedCategories,
      );
      if (_existing == null) {
        await repository.createPromotion(
          promotion,
          productIds: _selectedProducts,
          categoryIds: _selectedCategories,
          productConditions: productConditions,
        );
      } else {
        await repository.updatePromotion(
          promotion,
          productIds: _selectedProducts,
          categoryIds: _selectedCategories,
          productConditions: productConditions,
        );
      }
      ref.invalidate(promotionsProvider);
      ref.invalidate(getProductsProvider);
      if (mounted) {
        setState(() {
          _dirty = false;
          _saving = false;
        });
        context.pop();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la promoción: $error')),
      );
      setState(() => _saving = false);
    }
  }

  DateTime? _optionalDate(String value) {
    if (value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    if (_allProducts == null || _allCategories == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final query = effectiveSearchQuery(_productSearch.text).toLowerCase();
    final products = _allProducts!.where((product) {
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
    }).toList();

    return PopScope<Object?>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _existing == null ? 'Nueva promoción' : 'Editar promoción',
          ),
          leading: IconButton(
            tooltip: 'Volver a promociones',
            onPressed: _saving
                ? null
                : _dirty
                ? _confirmDiscard
                : () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            _existing == null ? 'Crear promoción' : 'Guardar cambios',
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 104),
              children: [
                Text(
                  'Datos de la promoción',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _discount,
                  decoration: const InputDecoration(
                    labelText: 'Descuento %',
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _conditions,
                  decoration: const InputDecoration(labelText: 'Condiciones'),
                  maxLines: 3,
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fields = [
                      _dateField(
                        _startDate,
                        'Fecha de inicio',
                        'Opcional · AAAA-MM-DD',
                      ),
                      _dateField(
                        _endDate,
                        'Fecha de fin',
                        'Opcional · AAAA-MM-DD',
                      ),
                    ];
                    if (constraints.maxWidth < 620) {
                      return Column(
                        children: [
                          fields[0],
                          const SizedBox(height: 12),
                          fields[1],
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 16),
                        Expanded(child: fields[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Promoción activa'),
                  value: _isActive,
                  onChanged: (value) => setState(() {
                    _isActive = value;
                    _dirty = true;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aplica a todos los productos'),
                  subtitle: const Text(
                    'Desactívalo para elegir categorías y productos específicos.',
                  ),
                  value: _appliesToAll,
                  onChanged: (value) => setState(() {
                    _appliesToAll = value;
                    _dirty = true;
                  }),
                ),
                if (!_appliesToAll) ...[
                  const Divider(height: 32),
                  Text(
                    'Alcance de la promoción',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Categorías completas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final category in _allCategories!)
                        FilterChip(
                          label: Text(category.name),
                          selected: _selectedCategories.contains(category.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _selectedCategories.add(category.id);
                            } else {
                              _selectedCategories.remove(category.id);
                            }
                            _dirty = true;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Productos específicos · ${_selectedProducts.length} '
                    '${_selectedProducts.length == 1 ? 'seleccionado' : 'seleccionados'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _productSearch,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Buscar productos',
                      hintText: 'Nombre, código o descripción',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _productSearch.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () {
                                _productSearch.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 380),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: products.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text('No hay productos que coincidan.'),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: products.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final product = products[index];
                              final selected = _selectedProducts.contains(
                                product.id,
                              );
                              final conditionController =
                                  _productConditionControllers.putIfAbsent(
                                    product.id,
                                    TextEditingController.new,
                                  );
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CheckboxListTile(
                                    value: selected,
                                    onChanged: (value) => setState(() {
                                      if (value == true) {
                                        _selectedProducts.add(product.id);
                                      } else {
                                        _selectedProducts.remove(product.id);
                                      }
                                      _dirty = true;
                                    }),
                                    secondary: _ProductSelectionImage(
                                      product: product,
                                    ),
                                    title: Text(
                                      product.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${product.sku} · ${product.description}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.trailing,
                                  ),
                                  if (selected)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        72,
                                        0,
                                        16,
                                        12,
                                      ),
                                      child: TextField(
                                        controller: conditionController,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Condición para ${product.name}',
                                          hintText: 'Ej. Mínimo de compra: 12 unidades',
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        onChanged: (_) => _markDirty(),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField(
    TextEditingController controller,
    String label,
    String hint,
  ) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label, hintText: hint),
    onChanged: (_) => _markDirty(),
  );
}

class _ProductSelectionImage extends StatelessWidget {
  const _ProductSelectionImage({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    return Semantics(
      label: 'Imagen de ${product.name}',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox.square(
          dimension: 52,
          child: url == null || url.isEmpty
              ? ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.inventory_2_outlined),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
        ),
      ),
    );
  }
}
