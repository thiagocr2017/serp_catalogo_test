import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/configuration/settings_providers.dart';
import '../../../inventory/domain/entities/audit_entry.dart';
import '../../../inventory/domain/entities/inventory_transaction.dart';
import '../../di/product_providers.dart';
import '../../di/promotion_providers.dart';
import '../../domain/entities/product.dart';
import '../controllers/product_list_controller.dart';

class ProductProfilePage extends ConsumerWidget {
  const ProductProfilePage({required this.productId, super.key});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productByIdProvider(productId));
    return product.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('No fue posible cargar: $e')),
      ),
      data: (value) => value == null
          ? const Scaffold(body: Center(child: Text('Producto no encontrado')))
          : _Profile(product: value),
    );
  }
}

class _Profile extends ConsumerWidget {
  const _Profile({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(productTransactionsProvider(product.id));
    final audit = ref.watch(productAuditProvider(product.id));
    final settings = ref.watch(businessSettingsProvider).value;
    final packagingLabel = switch (product.packagingType) {
      PackagingType.unit => settings?.packagingUnitLabel ?? 'Unidad',
      PackagingType.box => settings?.packagingBoxLabel ?? 'Caja',
      PackagingType.set => settings?.packagingSetLabel ?? 'Set',
    };
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/products'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('${product.sku} · ${product.name}'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/products/${product.id}/edit'),
            icon: const Icon(Icons.edit),
            label: const Text('Editar'),
          ),
          TextButton.icon(
            onPressed: () => _changeStatus(context, ref),
            icon: Icon(
              product.isActive
                  ? Icons.visibility_off_outlined
                  : Icons.check_circle_outline,
            ),
            label: Text(product.isActive ? 'Desactivar' : 'Activar'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 320,
                    height: 320,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: product.imageUrl == null
                        ? const Icon(Icons.inventory_2_outlined, size: 80)
                        : Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            alignment: Alignment(
                              (product.imagePositionX * 2) - 1,
                              (product.imagePositionY * 2) - 1,
                            ),
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image_outlined,
                              size: 80,
                            ),
                          ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          product.sku,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(product.description),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _Metric(
                label: 'Precio unitario',
                value:
                    'USD ${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
                icon: Icons.attach_money,
              ),
              _Metric(
                label: 'Stock actual',
                value: '${product.currentStock}',
                icon: Icons.inventory_2,
              ),
              _Metric(
                label: 'Venta mínima',
                value: '${product.minimumSaleQuantity} $packagingLabel',
                icon: Icons.all_inbox,
              ),
              _Metric(
                label: 'CBM por MOQ',
                value: product.cbmPerMoq.toStringAsFixed(6),
                icon: Icons.view_in_ar,
              ),
              _Metric(
                label: 'Costo fábrica',
                value:
                    'USD ${(product.factoryCostInCents / 100).toStringAsFixed(2)}',
                icon: Icons.factory,
              ),
              _Metric(
                label: 'MOQ de recompra',
                value: '${product.minimumOrderQuantity}',
                icon: Icons.shopping_cart_checkout,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Section(title: 'Descripción', child: Text(product.description)),
          const SizedBox(height: 16),
          _PricingCalculator(product: product),
          const SizedBox(height: 16),
          _Section(
            title: 'Promoción aplicada',
            child: product.promotionPriceInCents == null
                ? const Text('Sin promoción activa.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${product.promotionType == PromotionType.bulk ? 'Masiva' : 'Individual'} · Precio original USD ${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
                      ),
                      Text(
                        'Precio final USD ${(product.promotionPriceInCents! / 100).toStringAsFixed(2)}',
                      ),
                      if (product.promotionType == PromotionType.bulk) ...[
                        const SizedBox(height: 8),
                        Text(
                          product.bulkPromotionName ?? 'Promoción masiva',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (product.bulkPromotionConditions?.isNotEmpty == true)
                          Text(product.bulkPromotionConditions!),
                        const SizedBox(height: 16),
                        _BulkProductConditionEditor(product: product),
                      ] else if (product.promotionText?.isNotEmpty == true)
                        Text(product.promotionText!),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Historial de inventario',
            child: transactions.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (items) => _SearchableHistory<InventoryTransaction>(
                searchLabel: 'Buscar en historial de inventario',
                emptyText: 'Sin movimientos de inventario.',
                items: [...items]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
                searchableText: (item) => [
                  _inventoryReason(item.reason),
                  item.quantity,
                  item.notes,
                  item.createdAt.toLocal(),
                ].join(' '),
                itemBuilder: (context, item) => ListTile(
                  dense: true,
                  leading: Icon(
                    item.quantity > 0
                        ? Icons.add_circle_outline
                        : Icons.remove_circle_outline,
                  ),
                  title: Text(
                    '${item.quantity > 0 ? '+' : ''}${item.quantity} · ${_inventoryReason(item.reason)}',
                  ),
                  subtitle: Text(
                    '${item.notes?.trim().isEmpty ?? true ? 'Sin notas' : item.notes} · ${item.createdAt.toLocal()}',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Historial de cambios y costos',
            child: audit.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (items) {
                final filtered = items.where(_isUsefulProductChange).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return filtered.isEmpty
                    ? const Text('Sin cambios registrados.')
                    : _SearchableHistory<AuditEntry>(
                        searchLabel: 'Buscar en cambios y costos',
                        emptyText: 'No hay cambios que coincidan.',
                        items: filtered,
                        searchableText: (item) => [
                          _productFieldLabel(item.fieldName),
                          item.oldValue,
                          item.newValue,
                          item.actorName,
                          item.createdAt.toLocal(),
                        ].join(' '),
                        itemBuilder: (context, item) => ListTile(
                          dense: true,
                          title: Text(
                            '${_productFieldLabel(item.fieldName)}: ${_auditValue(item.fieldName, item.oldValue)} → ${_auditValue(item.fieldName, item.newValue)}',
                          ),
                          subtitle: Text(
                            '${item.createdAt.toLocal()} · ${item.actorName ?? 'Sistema'}',
                          ),
                        ),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _inventoryReason(InventoryReason reason) => switch (reason) {
    InventoryReason.initialStock => 'Stock inicial',
    InventoryReason.purchase => 'Compra',
    InventoryReason.sale => 'Venta',
    InventoryReason.adjustment => 'Ajuste',
    InventoryReason.returnItem => 'Devolución',
    InventoryReason.reversal => 'Reversión',
  };

  bool _isUsefulProductChange(AuditEntry entry) =>
      (entry.oldValue != null || entry.newValue != null) &&
      const {
        'name',
        'sku',
        'barcode',
        'description',
        'category_id',
        'unit_price',
        'package_price',
        'factory_cost',
        'min_order_quantity',
        'minimum_sale_quantity',
        'packaging_type',
        'cbm_per_moq',
        'reorder_point',
        'promo_price',
        'promo_text',
        'image_url',
        'image_position_x',
        'image_position_y',
        'is_active',
      }.contains(entry.fieldName);

  String _auditValue(String field, String? value) {
    if (field == 'image_url') {
      return value == null || value.isEmpty ? 'Sin imagen' : 'Imagen asignada';
    }
    if (field == 'is_active') {
      return value == null
          ? 'Sin definir'
          : value == 'true'
          ? 'Activo'
          : 'Inactivo';
    }
    return value ?? '∅';
  }

  String _productFieldLabel(String field) => switch (field) {
    'name' => 'Nombre',
    'sku' => 'Código',
    'barcode' => 'Código de barras',
    'description' => 'Descripción',
    'category_id' => 'Categoría',
    'unit_price' => 'Precio unitario',
    'package_price' => 'Precio por empaque',
    'factory_cost' => 'Costo de fábrica',
    'min_order_quantity' => 'MOQ de recompra',
    'minimum_sale_quantity' => 'Venta mínima',
    'packaging_type' => 'Presentación',
    'cbm_per_moq' => 'CBM por MOQ',
    'reorder_point' => 'Punto de reorden',
    'promo_price' => 'Precio promocional individual',
    'promo_text' => 'Condición promocional individual',
    'image_url' => 'Imagen',
    'image_position_x' => 'Posición horizontal de imagen',
    'image_position_y' => 'Posición vertical de imagen',
    'is_active' => 'Estado activo',
    _ => field.replaceAll('_', ' '),
  };

  // TODO: Remove after the full-page editor has completed its transition period.
  // ignore: unused_element
  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(text: product.name);
    final description = TextEditingController(text: product.description);
    final price = TextEditingController(
      text: (product.unitPriceInCents / 100).toStringAsFixed(2),
    );
    final factory = TextEditingController(
      text: (product.factoryCostInCents / 100).toStringAsFixed(2),
    );
    final promo = TextEditingController(
      text:
          product.promotionPriceInCents == null ||
              product.promotionType == PromotionType.bulk
          ? ''
          : (product.promotionPriceInCents! / 100).toStringAsFixed(2),
    );
    final promoText = TextEditingController(text: product.promotionText ?? '');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar producto'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              TextField(
                controller: price,
                decoration: const InputDecoration(labelText: 'Precio unitario'),
              ),
              TextField(
                controller: factory,
                decoration: const InputDecoration(labelText: 'Costo fábrica'),
              ),
              TextField(
                controller: promo,
                decoration: const InputDecoration(
                  labelText: 'Precio promoción individual',
                ),
              ),
              TextField(
                controller: promoText,
                decoration: const InputDecoration(
                  labelText: 'Condiciones promoción',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      int cents(String text) => (double.parse(text) * 100).round();
      final updated = Product(
        id: product.id,
        sku: product.sku,
        barcode: product.barcode,
        name: name.text.trim(),
        description: description.text.trim(),
        categoryId: product.categoryId,
        unitPriceInCents: cents(price.text),
        packagePriceInCents: product.packagePriceInCents,
        minimumOrderQuantity: product.minimumOrderQuantity,
        packagingType: product.packagingType,
        cbmPerMoq: product.cbmPerMoq,
        factoryCostInCents: cents(factory.text),
        imageUrl: product.imageUrl,
        imagePositionX: product.imagePositionX,
        imagePositionY: product.imagePositionY,
        currentStock: product.currentStock,
        reorderPoint: product.reorderPoint,
        promotionPriceInCents: promo.text.trim().isEmpty
            ? null
            : cents(promo.text),
        promotionText: promoText.text.trim().isEmpty
            ? null
            : promoText.text.trim(),
        promotionType: promo.text.trim().isEmpty
            ? null
            : PromotionType.individual,
        isActive: product.isActive,
        createdAt: product.createdAt,
        updatedAt: DateTime.now().toUtc(),
        deletedAt: product.deletedAt,
      );
      await ref.read(saveProductProvider).update(updated);
      ref.invalidate(productByIdProvider(product.id));
      ref.invalidate(productListControllerProvider);
    }
    name.dispose();
    description.dispose();
    price.dispose();
    factory.dispose();
    promo.dispose();
    promoText.dispose();
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref) async {
    final activating = !product.isActive;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activating ? 'Activar producto' : 'Desactivar producto'),
        content: Text(
          activating
              ? 'El producto volverá a aparecer entre los productos activos.'
              : 'El producto dejará de aparecer entre los activos, pero conservará todo su historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(activating ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      if (activating) {
        final activated = Product(
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
          packagingType: product.packagingType,
          cbmPerMoq: product.cbmPerMoq,
          factoryCostInCents: product.factoryCostInCents,
          imageUrl: product.imageUrl,
          imagePositionX: product.imagePositionX,
          imagePositionY: product.imagePositionY,
          currentStock: product.currentStock,
          reorderPoint: product.reorderPoint,
          promotionPriceInCents: product.promotionPriceInCents,
          promotionText: product.promotionText,
          promotionType: product.promotionType,
          isActive: true,
          createdAt: product.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
        await ref.read(saveProductProvider).update(activated);
      } else {
        await ref.read(deactivateProductProvider)(product.id);
      }
      ref.invalidate(productByIdProvider(product.id));
      ref.invalidate(productListControllerProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activating ? 'Producto activado' : 'Producto desactivado',
            ),
          ),
        );
      }
    }
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      width: 190,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(label),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          child,
        ],
      ),
    ),
  );
}

class _SearchableHistory<T> extends StatefulWidget {
  const _SearchableHistory({
    required this.searchLabel,
    required this.emptyText,
    required this.items,
    required this.searchableText,
    required this.itemBuilder,
  });

  final String searchLabel;
  final String emptyText;
  final List<T> items;
  final String Function(T item) searchableText;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  State<_SearchableHistory<T>> createState() => _SearchableHistoryState<T>();
}

class _SearchableHistoryState<T> extends State<_SearchableHistory<T>> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.items
        .where(
          (item) =>
              query.isEmpty ||
              widget.searchableText(item).toLowerCase().contains(query),
        )
        .toList();
    return Column(
      children: [
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            labelText: widget.searchLabel,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.emptyText),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: filtered.length > 4,
              child: ListView.separated(
                controller: _scroll,
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    widget.itemBuilder(context, filtered[index]),
              ),
            ),
          ),
      ],
    );
  }
}

class _BulkProductConditionEditor extends ConsumerStatefulWidget {
  const _BulkProductConditionEditor({required this.product});

  final Product product;

  @override
  ConsumerState<_BulkProductConditionEditor> createState() =>
      _BulkProductConditionEditorState();
}

class _BulkProductConditionEditorState
    extends ConsumerState<_BulkProductConditionEditor> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.product.bulkProductConditions ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descripción específica para este producto',
              hintText: 'Ej. Para este código debe comprar al menos 6 unidades',
              helperText:
                  'Solo modifica este producto dentro de la promoción masiva.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Guardar descripción'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final promotionId = widget.product.bulkPromotionId;
    if (promotionId == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(promotionRepositoryProvider)
          .setProductCondition(
            promotionId: promotionId,
            productId: widget.product.id,
            conditionsText: _controller.text,
          );
      ref.invalidate(productByIdProvider(widget.product.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descripción promocional guardada.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PricingCalculator extends StatefulWidget {
  const _PricingCalculator({required this.product});
  final Product product;
  @override
  State<_PricingCalculator> createState() => _PricingCalculatorState();
}

class _PricingCalculatorState extends State<_PricingCalculator> {
  final expenses = TextEditingController(text: '0');
  final margin = TextEditingController(text: '30');
  @override
  void dispose() {
    expenses.dispose();
    margin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cost = widget.product.factoryCostInCents / 100;
    final result =
        (cost + (double.tryParse(expenses.text) ?? 0)) *
        (1 + (double.tryParse(margin.text) ?? 0) / 100);
    return _Section(
      title: 'Herramienta de precios',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'El precio recomendado suma el costo de fábrica y los gastos de '
            'importación por unidad. Después aplica el margen deseado sobre '
            'ese costo total.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Fórmula: (costo de fábrica + importación por unidad) × '
              '(1 + margen ÷ 100)',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: expenses,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Gastos de importación por unidad',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: margin,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Margen deseado %',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Costo base: USD ${cost.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Recomendado: USD ${result.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
