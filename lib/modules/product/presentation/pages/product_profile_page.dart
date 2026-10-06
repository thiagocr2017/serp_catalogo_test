import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utilities/phone_number.dart';
import '../../../../shared/navigation/unsaved_changes_guard.dart';
import '../../../inventory/inventory_module.dart';
import '../../../sales/sales_module.dart';
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
    final compact = MediaQuery.sizeOf(context).width < 700;
    final transactions = ref.watch(productTransactionsProvider(product.id));
    final locationBalances = ref.watch(
      productLocationBalancesProvider(product.id),
    );
    final audit = ref.watch(productAuditProvider(product.id));
    final packagingLabel =
        product.packagingPresentationName ?? 'Presentación no disponible';
    final marginPercent = product.unitPriceInCents > 0
        ? (product.unitPriceInCents -
                  product.factoryCostInCents -
                  product.extraCostsInCents) /
              product.unitPriceInCents *
              100
        : null;
    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: 'Volver a productos',
          child: IconButton(
            onPressed: () => context.go('/products'),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        title: Text(
          '${product.sku} · ${product.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: compact
            ? [
                PopupMenuButton<String>(
                  tooltip: 'Acciones del producto',
                  onSelected: (value) {
                    if (value == 'edit') {
                      context.go('/products/${product.id}/edit');
                    } else {
                      _changeStatus(context, ref);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(
                      value: 'status',
                      child: Text(product.isActive ? 'Desactivar' : 'Activar'),
                    ),
                  ],
                ),
              ]
            : [
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
        padding: EdgeInsets.all(compact ? 12 : 28),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.all(compact ? 12 : 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 600;
                  final image = Container(
                    width: stacked ? null : 320,
                    height: stacked ? 220 : 320,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: product.imageUrl == null
                        ? const Icon(Icons.inventory_2_outlined, size: 80)
                        : FractionalTranslation(
                            translation: Offset(
                              (product.imagePositionX - .5) * .9,
                              (product.imagePositionY - .5) * .9,
                            ),
                            child: Transform.scale(
                              scale: product.imageScale,
                              child: Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.broken_image_outlined,
                                  size: 80,
                                ),
                              ),
                            ),
                          ),
                  );
                  final summary = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusChip(
                            label: product.isActive ? 'Activo' : 'Inactivo',
                            icon: product.isActive
                                ? Icons.check_circle_outline
                                : Icons.visibility_off_outlined,
                            color: product.isActive ? Colors.green : Colors.red,
                          ),
                          if (product.isOutOfStock)
                            const _StatusChip(
                              label: 'Sin stock',
                              icon: Icons.remove_shopping_cart_outlined,
                              color: Colors.red,
                            )
                          else if (product.requiresRestock)
                            _StatusChip(
                              label: 'Reponer (punto: ${product.reorderPoint})',
                              icon: Icons.warning_amber_outlined,
                              color: Colors.orange,
                            )
                          else
                            const _StatusChip(
                              label: 'En stock',
                              icon: Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                          if (product.promotionPriceInCents != null)
                            const _StatusChip(
                              label: 'Con promoción',
                              icon: Icons.local_offer_outlined,
                              color: Colors.purple,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CopyableValue(prefix: 'SKU', value: product.sku),
                          if (product.barcode?.trim().isNotEmpty == true)
                            _CopyableValue(
                              prefix: 'Código de barras',
                              value: product.barcode!.trim(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(product.description),
                    ],
                  );
                  return stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            image,
                            const SizedBox(height: 16),
                            summary,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            image,
                            const SizedBox(width: 28),
                            Expanded(child: summary),
                          ],
                        );
                },
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
                subtitle: product.promotionPriceInCents == null
                    ? null
                    : 'Promoción: USD ${(product.promotionPriceInCents! / 100).toStringAsFixed(2)}',
              ),
              _Metric(
                label: 'Stock actual',
                value: '${product.currentStock}',
                icon: Icons.inventory_2,
                color: product.isOutOfStock
                    ? Colors.red
                    : product.requiresRestock
                    ? Colors.orange
                    : Colors.green,
                subtitle: 'Punto de reorden: ${product.reorderPoint}',
              ),
              _Metric(
                label: 'Margen actual',
                value: marginPercent == null
                    ? '—'
                    : '${marginPercent.toStringAsFixed(1)} %',
                icon: Icons.percent,
                color: marginPercent != null && marginPercent < 0
                    ? Colors.red
                    : null,
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
          _Section(
            title: 'Ubicación y stock por almacén',
            trailing: TextButton.icon(
              onPressed: () => context.go(
                '/inventory?productId=${product.id}'
                '&sku=${Uri.encodeComponent(product.sku)}',
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Ver en Inventario'),
            ),
            child: _LocationBalances(
              balances: locationBalances,
              productStock: product.currentStock,
            ),
          ),
          const SizedBox(height: 16),
          _ProductBuyers(productId: product.id),
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
              data: (items) => _SearchableHistory<InventoryTransactionDto>(
                searchLabel: 'Buscar en historial de inventario',
                emptyText: 'Sin movimientos de inventario.',
                items: [...items]..sort(compareInventoryHistory),
                searchableText: (item) => [
                  describeInventoryTransaction(item, items),
                  item.documentNumber,
                  item.quantity,
                  item.notes,
                  item.createdAt.toLocal(),
                ].join(' '),
                itemBuilder: (context, item) {
                  final description = describeInventoryTransaction(item, items);
                  final notes = item.notes?.trim();
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      item.quantity > 0
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                    ),
                    title: Text(
                      '${item.quantity > 0 ? '+' : ''}${item.quantity} · $description',
                    ),
                    subtitle: Text(
                      [
                        if (item.documentNumber?.trim().isNotEmpty == true)
                          'Doc. ${item.documentNumber!.trim()}',
                        if (notes != null && notes.isNotEmpty) notes,
                        '${item.createdAt.toLocal()}',
                      ].join(' · '),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Historial de cambios de costos y precios',
            child: audit.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (items) {
                final filtered = items.where(_isCostOrPriceChange).toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return filtered.isEmpty
                    ? const Text('Sin cambios de costos o precios registrados.')
                    : _SearchableHistory<AuditEntryDto>(
                        searchLabel: 'Buscar en historial de costos y precios',
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

  /// Solo se muestra el histórico de costo de fábrica y precios
  /// (unitario y por empaque) del producto.
  bool _isCostOrPriceChange(AuditEntryDto entry) =>
      (entry.oldValue != null || entry.newValue != null) &&
      const {
        'factory_cost',
        'unit_price',
        'package_price',
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
    var dirty = false;
    final accepted = await showDialog<bool>(
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
            if (discard && context.mounted) navigator.pop(false);
          }

          return PopScope(
            canPop: !dirty,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await cancel();
            },
            child: AlertDialog(
              title: const Text('Editar producto'),
              content: SizedBox(
                width: 520,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      onChanged: (_) => markDirty(),
                    ),
                    TextField(
                      controller: description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                      onChanged: (_) => markDirty(),
                    ),
                    TextField(
                      controller: price,
                      decoration: const InputDecoration(
                        labelText: 'Precio unitario',
                      ),
                      onChanged: (_) => markDirty(),
                    ),
                    TextField(
                      controller: factory,
                      decoration: const InputDecoration(
                        labelText: 'Costo fábrica',
                      ),
                      onChanged: (_) => markDirty(),
                    ),
                    TextField(
                      controller: promo,
                      decoration: const InputDecoration(
                        labelText: 'Precio promoción individual',
                      ),
                      onChanged: (_) => markDirty(),
                    ),
                    TextField(
                      controller: promoText,
                      decoration: const InputDecoration(
                        labelText: 'Condiciones promoción',
                      ),
                      onChanged: (_) => markDirty(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: cancel, child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          );
        },
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
        packagingPresentationId: product.packagingPresentationId,
        packagingPresentationName: product.packagingPresentationName,
        cbmPerMoq: product.cbmPerMoq,
        factoryCostInCents: cents(factory.text),
        imageUrl: product.imageUrl,
        imagePositionX: product.imagePositionX,
        imagePositionY: product.imagePositionY,
        imageScale: product.imageScale,
        catalogSortOrder: product.catalogSortOrder,
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
          packagingPresentationId: product.packagingPresentationId,
          packagingPresentationName: product.packagingPresentationName,
          cbmPerMoq: product.cbmPerMoq,
          factoryCostInCents: product.factoryCostInCents,
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

class _LocationBalances extends StatelessWidget {
  const _LocationBalances({required this.balances, required this.productStock});

  final AsyncValue<List<InventoryBalanceDto>> balances;
  final int productStock;

  @override
  Widget build(BuildContext context) => balances.when(
    loading: () => const LinearProgressIndicator(),
    error: (e, _) => Text('No fue posible cargar ubicaciones: $e'),
    data: (items) {
      final visible = items.where((item) => item.quantity != 0).toList()
        ..sort((a, b) {
          if (a.quantity != b.quantity) return b.quantity.compareTo(a.quantity);
          final warehouse = (a.warehouseName ?? '').compareTo(
            b.warehouseName ?? '',
          );
          if (warehouse != 0) return warehouse;
          return (a.locationName ?? '').compareTo(b.locationName ?? '');
        });

      if (visible.isEmpty) {
        return const Text('Sin stock registrado en almacenes o ubicaciones.');
      }

      final total = visible.fold<int>(0, (sum, item) => sum + item.quantity);
      final difference = total - productStock;
      final warehouseTotals = <String, int>{};
      for (final item in visible) {
        final name = item.warehouseName ?? 'Almacén sin nombre';
        warehouseTotals.update(
          name,
          (value) => value + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
      final groups = [
        for (final entry in warehouseTotals.entries)
          if (entry.value > 0)
            _WarehouseGroup(name: entry.key, quantity: entry.value),
      ]..sort((a, b) => b.quantity.compareTo(a.quantity));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: 'Total ubicado: $total',
                icon: Icons.inventory_2_outlined,
                color: Colors.blue,
              ),
              _StatusChip(
                label: '${visible.length} ubicación(es)',
                icon: Icons.location_on_outlined,
                color: Colors.blueGrey,
              ),
              if (difference != 0)
                _StatusChip(
                  label: difference > 0
                      ? '$difference unidad(es) de más frente al stock del producto'
                      : '${difference.abs()} unidad(es) de menos frente al stock del producto',
                  icon: Icons.sync_problem_outlined,
                  color: Colors.orange,
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = [
                for (final item in visible)
                  _LocationBalanceTile(
                    balance: item,
                    share: total == 0
                        ? 0.0
                        : (item.quantity / total).clamp(0.0, 1.0).toDouble(),
                  ),
              ];
              Widget tileGrid() => constraints.maxWidth < 720
                  ? Column(
                      children: [
                        for (final tile in tiles)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: tile,
                          ),
                      ],
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tile in tiles)
                          SizedBox(width: 340, child: tile),
                      ],
                    );
              if (groups.isEmpty) return tileGrid();
              if (constraints.maxWidth < 880) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tileGrid(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 300,
                      child: _WarehouseDistribution(groups: groups),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tileGrid()),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 300,
                    child: _WarehouseDistribution(groups: groups),
                  ),
                ],
              );
            },
          ),
        ],
      );
    },
  );
}

class _ProductBuyers extends ConsumerStatefulWidget {
  const _ProductBuyers({required this.productId});

  final String productId;

  @override
  ConsumerState<_ProductBuyers> createState() => _ProductBuyersState();
}

class _ProductBuyersState extends ConsumerState<_ProductBuyers> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyers = ref.watch(productBuyersProvider(widget.productId));
    return _Section(
      title: 'Clientes que compran este producto',
      child: buyers.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('No fue posible cargar compradores: $e'),
        data: (items) {
          final filtered = filterProductBuyers(items, _query);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  labelText: 'Buscar comprador',
                  hintText: 'Negocio, contacto, provincia o gira',
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
              if (items.isEmpty)
                const Text(
                  'Aún no hay compras registradas de este producto '
                  'en facturas ni pedidos.',
                )
              else if (filtered.isEmpty)
                const Text(
                  'Sin coincidencias. Prueba con otro negocio, contacto, '
                  'provincia o gira.',
                )
              else
                for (final buyer in filtered) _BuyerTile(buyer: buyer),
            ],
          );
        },
      ),
    );
  }
}

class _BuyerTile extends StatelessWidget {
  const _BuyerTile({required this.buyer});

  final ProductBuyerDto buyer;

  @override
  Widget build(BuildContext context) {
    final place = [
      if (buyer.gira?.trim().isNotEmpty == true) 'Gira ${buyer.gira!.trim()}',
      if (buyer.province?.trim().isNotEmpty == true) buyer.province!.trim(),
    ].join(' · ');
    final contacts = buyer.contacts
        .map(
          (contact) => [
            contact.name,
            if (contact.role?.trim().isNotEmpty == true)
              '(${contact.role!.trim()})',
            if (contact.phone?.trim().isNotEmpty == true)
              displayPhone(contact.phone),
          ].join(' '),
        )
        .join(' · ');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(buyer.isActive ? buyer.name : '${buyer.name} (Inactivo)'),
      subtitle: Text(
        [
          if (place.isNotEmpty) place,
          if (contacts.isNotEmpty) 'Contactos: $contacts',
          'Última compra: ${buyer.lastPurchaseAt == null ? '—' : buyer.lastPurchaseAt!.toLocal()}'
              ' · ${buyer.totalQuantity} uds en ${buyer.documentsCount} docs',
        ].join('\n'),
      ),
      isThreeLine: true,
    );
  }
}

class _WarehouseGroup {
  const _WarehouseGroup({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

const _distributionColors = <MaterialColor>[
  Colors.blue,
  Colors.teal,
  Colors.purple,
  Colors.orange,
  Colors.pink,
  Colors.cyan,
  Colors.indigo,
  Colors.amber,
];

class _WarehouseDistribution extends StatelessWidget {
  const _WarehouseDistribution({required this.groups});

  final List<_WarehouseGroup> groups;

  @override
  Widget build(BuildContext context) {
    final total = groups.fold<int>(0, (sum, group) => sum + group.quantity);
    final textTheme = Theme.of(context).textTheme;
    final colored = [
      for (var index = 0; index < groups.length; index++)
        (
          groups[index],
          _distributionColors[index % _distributionColors.length],
        ),
    ];
    const chartSize = 150.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: chartSize,
            height: chartSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(chartSize, chartSize),
                  painter: _DistributionPainter(
                    values: [for (final entry in colored) entry.$1.quantity],
                    colors: [for (final entry in colored) entry.$2],
                    total: total,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total', style: textTheme.headlineSmall),
                    Text('unidades', style: textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _DistributionTable(rows: colored, total: total),
      ],
    );
  }
}

class _DistributionTable extends StatelessWidget {
  const _DistributionTable({required this.rows, required this.total});

  final List<(_WarehouseGroup, MaterialColor)> rows;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final headerStyle = textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final valueStyle = textTheme.labelLarge;
    final divider = BorderSide(color: theme.dividerColor);

    Widget cell(
      Widget child, {
      required int column,
      bool header = false,
      bool last = false,
    }) => Container(
      padding: EdgeInsets.only(
        top: header ? 0 : 8,
        bottom: header ? 6 : 8,
        left: column == 0 ? 0 : 6,
        right: column == 0 ? 6 : 0,
      ),
      decoration: last ? null : BoxDecoration(border: Border(bottom: divider)),
      child: child,
    );

    Widget number(String value, {TextStyle? style}) =>
        Text(value, textAlign: TextAlign.right, style: style ?? valueStyle);

    final lastIndex = rows.length - 1;
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1.4),
        2: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          children: [
            cell(Text('Almacén', style: headerStyle), column: 0, header: true),
            cell(
              number('Unidades', style: headerStyle),
              column: 1,
              header: true,
            ),
            cell(number('%', style: headerStyle), column: 2, header: true),
          ],
        ),
        for (var index = 0; index < rows.length; index++)
          TableRow(
            children: [
              cell(
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: rows[index].$2,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rows[index].$1.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                column: 0,
                last: index == lastIndex,
              ),
              cell(
                number('${rows[index].$1.quantity}'),
                column: 1,
                last: index == lastIndex,
              ),
              cell(
                number(
                  total == 0
                      ? '0'
                      : (rows[index].$1.quantity * 100 / total).toStringAsFixed(
                          0,
                        ),
                ),
                column: 2,
                last: index == lastIndex,
              ),
            ],
          ),
        TableRow(
          children: [
            cell(
              Text(
                'Total',
                style: valueStyle?.copyWith(fontWeight: FontWeight.w700),
              ),
              column: 0,
            ),
            cell(
              number(
                '$total',
                style: valueStyle?.copyWith(fontWeight: FontWeight.w700),
              ),
              column: 1,
            ),
            cell(
              number(
                '100',
                style: valueStyle?.copyWith(fontWeight: FontWeight.w700),
              ),
              column: 2,
            ),
          ],
        ),
      ],
    );
  }
}

class _DistributionPainter extends CustomPainter {
  const _DistributionPainter({
    required this.values,
    required this.colors,
    required this.total,
  });

  final List<int> values;
  final List<MaterialColor> colors;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || values.isEmpty) return;
    const stroke = 24.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var startAngle = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = 2 * math.pi * (values[index] / total);
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = colors[index % colors.length],
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DistributionPainter oldDelegate) =>
      oldDelegate.total != total ||
      oldDelegate.values != values ||
      oldDelegate.colors != colors;
}

class _LocationBalanceTile extends StatelessWidget {
  const _LocationBalanceTile({required this.balance, required this.share});

  final InventoryBalanceDto balance;
  final double share;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.warehouse_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    balance.warehouseName ?? 'Almacén sin nombre',
                    style: textTheme.titleSmall,
                  ),
                  Text(
                    balance.locationName ?? 'Ubicación sin nombre',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: share, minHeight: 6),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${balance.quantity}', style: textTheme.titleLarge),
                Text(
                  '${(share * 100).toStringAsFixed(0)} %',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16, color: color.shade700),
    label: Text(
      label,
      style: TextStyle(color: color.shade800, fontWeight: FontWeight.w600),
    ),
    backgroundColor: color.shade100,
    visualDensity: VisualDensity.compact,
  );
}

class _CopyableValue extends StatelessWidget {
  const _CopyableValue({required this.prefix, required this.value});

  final String prefix;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2, right: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '$prefix: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          IconButton(
            tooltip: 'Copiar $prefix',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            iconSize: 16,
            icon: const Icon(Icons.copy, size: 16),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$prefix copiado: $value'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;
  final MaterialColor? color;
  @override
  Widget build(BuildContext context) => Card(
    child: SizedBox(
      width: 190,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color?.shade700),
            const SizedBox(height: 12),
            Text(label),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color?.shade800,
                fontWeight: color == null ? null : FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ?trailing,
            ],
          ),
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
