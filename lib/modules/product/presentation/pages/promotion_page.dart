import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../di/product_providers.dart';
import '../../di/promotion_providers.dart';
import '../../domain/entities/bulk_promotion.dart';
import '../../domain/entities/product_query.dart';

class PromotionPage extends ConsumerStatefulWidget {
  const PromotionPage({super.key});

  @override
  ConsumerState<PromotionPage> createState() => _PromotionPageState();
}

class _PromotionPageState extends ConsumerState<PromotionPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promotions = ref.watch(promotionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Promociones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva promoción'),
      ),
      body: promotions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No fue posible cargar: $e')),
        data: (items) {
          final query = _query.trim().toLowerCase();
          final filtered = items.where((promotion) {
            if (query.isEmpty) return true;
            return promotion.name.toLowerCase().contains(query) ||
                promotion.conditionsText.toLowerCase().contains(query) ||
                promotion.discountPercentage.toString().contains(query);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    labelText: 'Buscar promociones',
                    hintText: 'Nombre, condición o porcentaje',
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
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No hay promociones que coincidan.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) {
                          final p = filtered[i];
                          return SwitchListTile(
                            value: p.isActive,
                            onChanged: (value) async {
                              await ref
                                  .read(promotionRepositoryProvider)
                                  .setActive(p.id, isActive: value);
                              ref.invalidate(promotionsProvider);
                            },
                            title: Text(
                              '${p.name} · ${p.discountPercentage.toStringAsFixed(2)}%',
                            ),
                            subtitle: Text(
                              '${p.appliesToAllProducts ? 'Todos los productos' : 'Selección específica'} · Hasta ${p.endDate.toLocal()}\n${p.conditionsText}',
                            ),
                            isThreeLine: true,
                            secondary: Icon(
                              p.isCurrentlyActive
                                  ? Icons.local_offer
                                  : Icons.event_busy,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final products = await ref.read(getProductsProvider)(
      const ProductQuery(isActive: true),
    );
    final categories = await ref.read(categoriesProvider.future);
    if (!context.mounted) return;
    final name = TextEditingController();
    final discount = TextEditingController();
    final conditions = TextEditingController();
    final listSelection = ref.read(selectedProductIdsProvider);
    var scope = listSelection.isEmpty ? 'all' : 'manual';
    final categoryIds = <String>{};
    final selected = <String>{...listSelection};
    final productConditions = <String, String>{};
    var endDate = DateTime.now().add(const Duration(days: 30));
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nueva promoción masiva'),
          content: SizedBox(
            width: 560,
            height: 520,
            child: ListView(
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: discount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Descuento %'),
                ),
                TextField(
                  controller: conditions,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Condiciones'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: scope,
                  decoration: const InputDecoration(labelText: 'Alcance'),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Todos los productos'),
                    ),
                    DropdownMenuItem(
                      value: 'category',
                      child: Text('Una o varias categorías'),
                    ),
                    DropdownMenuItem(
                      value: 'manual',
                      child: Text('Selección manual'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    scope = value!;
                    selected.clear();
                    categoryIds.clear();
                  }),
                ),
                if (scope == 'category') ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Categorías incluidas (selección congelada)'),
                  ),
                  for (final category in categories)
                    CheckboxListTile(
                      value: categoryIds.contains(category.id),
                      title: Text(category.name),
                      onChanged: (value) => setState(() {
                        value!
                            ? categoryIds.add(category.id)
                            : categoryIds.remove(category.id);
                        selected
                          ..clear()
                          ..addAll(
                            products
                                .where(
                                  (p) => categoryIds.contains(p.categoryId),
                                )
                                .map((p) => p.id),
                          );
                      }),
                    ),
                ],
                if (scope == 'manual') ...[
                  const Text('Productos incluidos'),
                  for (final p in products)
                    CheckboxListTile(
                      value: selected.contains(p.id),
                      title: Text('${p.sku} · ${p.name}'),
                      onChanged: (v) => setState(
                        () => v! ? selected.add(p.id) : selected.remove(p.id),
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Condición específica por producto'),
                  subtitle: const Text(
                    'Opcional: indica cantidades o requisitos particulares para cada código.',
                  ),
                  children: [
                    for (final product in products.where(
                      (product) =>
                          scope == 'all' || selected.contains(product.id),
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextFormField(
                          initialValue: productConditions[product.id],
                          decoration: InputDecoration(
                            labelText: '${product.sku} · ${product.name}',
                            hintText: 'Ej. Compra mínima de 6 unidades',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            if (value.trim().isEmpty) {
                              productConditions.remove(product.id);
                            } else {
                              productConditions[product.id] = value;
                            }
                          },
                        ),
                      ),
                  ],
                ),
                ListTile(
                  title: const Text('Fecha final'),
                  subtitle: Text('${endDate.toLocal()}'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1825)),
                      initialDate: endDate,
                    );
                    if (date != null) {
                      setState(
                        () => endDate = date.add(
                          const Duration(hours: 23, minutes: 59),
                        ),
                      );
                    }
                  },
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
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    final percentage = double.tryParse(discount.text.replaceAll(',', '.'));
    final validSelection = scope == 'all' || selected.isNotEmpty;
    if (accepted == true &&
        name.text.trim().isNotEmpty &&
        percentage != null &&
        percentage > 0 &&
        percentage <= 100 &&
        validSelection) {
      final promotion = BulkPromotion(
        id: const Uuid().v4(),
        name: name.text.trim(),
        discountPercentage: percentage,
        conditionsText: conditions.text.trim(),
        endDate: endDate,
        appliesToAllProducts: scope == 'all',
        isActive: true,
      );
      await ref
          .read(promotionRepositoryProvider)
          .createPromotion(
            promotion,
            productIds: scope == 'all' ? const <String>{} : selected,
            productConditions: productConditions,
          );
      ref.invalidate(promotionsProvider);
    } else if (accepted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete el nombre, un descuento entre 0 y 100 y el alcance.',
          ),
        ),
      );
    }
    name.dispose();
    discount.dispose();
    conditions.dispose();
  }
}
