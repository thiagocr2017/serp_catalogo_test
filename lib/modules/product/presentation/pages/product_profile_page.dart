import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../inventory/di/inventory_providers.dart';
import '../../di/product_providers.dart';
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/products'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('${product.sku} · ${product.name}'),
        actions: [
          TextButton.icon(
            onPressed: () => _edit(context, ref),
            icon: const Icon(Icons.edit),
            label: const Text('Editar'),
          ),
          TextButton.icon(
            onPressed: product.isActive
                ? () => _deactivate(context, ref)
                : null,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Desactivar'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(28),
        children: [
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
                label: 'MOQ',
                value:
                    '${product.minimumOrderQuantity} ${product.packagingType.name}',
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
            ],
          ),
          const SizedBox(height: 24),
          _Section(title: 'Descripción', child: Text(product.description)),
          const SizedBox(height: 16),
          _PricingCalculator(product: product),
          const SizedBox(height: 16),
          _Section(
            title: 'Promoción individual',
            child: product.promotionPriceInCents == null
                ? const Text('Sin promoción individual activa.')
                : Text(
                    'Precio promocional USD ${(product.promotionPriceInCents! / 100).toStringAsFixed(2)}\n${product.promotionText ?? ''}',
                  ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Historial de inventario',
            child: transactions.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (items) => Column(
                children: [
                  for (final item in items)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        item.quantity > 0
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                      ),
                      title: Text(
                        '${item.quantity > 0 ? '+' : ''}${item.quantity} · ${item.reason.name}',
                      ),
                      subtitle: Text(
                        '${item.notes ?? ''} · ${item.createdAt.toLocal()}',
                      ),
                    ),
                ],
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
                final filtered = items
                    .where(
                      (e) =>
                          e.fieldName == 'factory_cost' ||
                          e.fieldName == 'unit_price' ||
                          e.fieldName == 'current_stock',
                    )
                    .toList();
                return filtered.isEmpty
                    ? const Text('Sin cambios registrados.')
                    : Column(
                        children: [
                          for (final item in filtered)
                            ListTile(
                              dense: true,
                              title: Text(
                                '${item.fieldName}: ${item.oldValue ?? '∅'} → ${item.newValue ?? '∅'}',
                              ),
                              subtitle: Text(
                                '${item.createdAt.toLocal()} · ${item.actorName ?? 'Sistema'}',
                              ),
                            ),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

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
      text: product.promotionPriceInCents == null
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
        currentStock: product.currentStock,
        reorderPoint: product.reorderPoint,
        promotionPriceInCents: promo.text.trim().isEmpty
            ? null
            : cents(promo.text),
        promotionText: promoText.text.trim().isEmpty
            ? null
            : promoText.text.trim(),
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

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar producto'),
        content: const Text(
          'El producto dejará de aparecer entre los activos, pero conservará todo su historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await ref.read(deactivateProductProvider)(product.id);
      ref.invalidate(productListControllerProvider);
      if (context.mounted) context.go('/products');
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: expenses,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Gastos de importación por unidad',
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: margin,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Margen deseado %'),
            ),
          ),
          const SizedBox(width: 24),
          Text(
            'Sugerido: USD ${result.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
