import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/navigation/unsaved_changes_guard.dart';
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
        onPressed: () => _openEditor(context, ref),
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
                          final scopeLabel = p.appliesToAllProducts
                              ? 'Todos los productos'
                              : p.categoryIds.isNotEmpty
                              ? '${p.categoryIds.length} categoría(s), incluyendo productos futuros'
                              : '${p.productIds.length} producto(s) seleccionado(s)';
                          return ListTile(
                            title: Text(
                              '${p.name} · ${p.discountPercentage.toStringAsFixed(2)}%',
                            ),
                            subtitle: Text(
                              '$scopeLabel · Hasta ${p.endDate.toLocal()}\n${p.conditionsText}',
                            ),
                            isThreeLine: true,
                            leading: Icon(
                              p.isCurrentlyActive
                                  ? Icons.local_offer
                                  : Icons.event_busy,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: p.isActive,
                                  onChanged: (value) async {
                                    await ref
                                        .read(promotionRepositoryProvider)
                                        .setActive(p.id, isActive: value);
                                    ref.invalidate(promotionsProvider);
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Editar promoción',
                                  onPressed: () => _openEditor(context, ref, p),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
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

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, [
    BulkPromotion? existing,
  ]) async {
    final products = await ref.read(getProductsProvider)(
      const ProductQuery(isActive: true),
    );
    final categories = await ref.read(categoriesProvider.future);
    if (!context.mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se puede crear una promoción porque no existen productos activos.',
          ),
        ),
      );
      return;
    }
    final name = TextEditingController(text: existing?.name ?? '');
    final discount = TextEditingController(
      text: existing?.discountPercentage.toStringAsFixed(2) ?? '',
    );
    final conditions = TextEditingController(
      text: existing?.conditionsText ?? '',
    );
    final listSelection = ref.read(selectedProductIdsProvider);
    var scope = existing == null
        ? (listSelection.isEmpty ? 'all' : 'manual')
        : existing.appliesToAllProducts
        ? 'all'
        : existing.categoryIds.isNotEmpty
        ? 'category'
        : 'manual';
    final categoryIds = <String>{...?existing?.categoryIds};
    final selected = <String>{
      if (existing == null) ...listSelection,
      ...?existing?.productIds,
    };
    final productConditions = <String, String>{...?existing?.productConditions};
    var endDate =
        existing?.endDate ?? DateTime.now().add(const Duration(days: 30));
    String? nameError;
    String? discountError;
    String? selectionError;
    String? saveError;
    var saving = false;
    var dirty = false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void markDirty() {
            if (dirty) return;
            setState(() => dirty = true);
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
              title: Text(
                existing == null
                    ? 'Nueva promoción masiva'
                    : 'Editar promoción',
              ),
              content: SizedBox(
                width: 560,
                height: 520,
                child: ListView(
                  children: [
                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        errorText: nameError,
                      ),
                      onChanged: (_) {
                        markDirty();
                        setState(() => nameError = null);
                      },
                    ),
                    TextField(
                      controller: discount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          return RegExp(r'^\d{0,3}([\.,]\d{0,2})?$')
                                  .hasMatch(newValue.text)
                              ? newValue
                              : oldValue;
                        }),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Descuento %',
                        hintText: 'Ej. 15 o 12,50',
                        errorText: discountError,
                      ),
                      onChanged: (_) {
                        markDirty();
                        setState(() => discountError = null);
                      },
                    ),
                    TextField(
                      controller: conditions,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Condiciones',
                      ),
                      onChanged: (_) => markDirty(),
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
                        markDirty();
                        scope = value!;
                        selected.clear();
                        categoryIds.clear();
                        productConditions.clear();
                        selectionError = null;
                      }),
                    ),
                    if (selectionError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          selectionError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (scope == 'category') ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Categorías incluidas (también aplica a productos futuros)',
                        ),
                      ),
                      for (final category in categories)
                        CheckboxListTile(
                          value: categoryIds.contains(category.id),
                          title: Text(category.name),
                          onChanged: (value) => setState(() {
                            markDirty();
                            value!
                                ? categoryIds.add(category.id)
                                : categoryIds.remove(category.id);
                            selectionError = null;
                          }),
                        ),
                    ],
                    if (scope == 'manual') ...[
                      const Text('Productos incluidos'),
                      for (final p in products)
                        CheckboxListTile(
                          value: selected.contains(p.id),
                          title: Text('${p.sku} · ${p.name}'),
                          onChanged: (v) => setState(() {
                            markDirty();
                            v! ? selected.add(p.id) : selected.remove(p.id);
                            selectionError = null;
                          }),
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
                              scope == 'all' ||
                              selected.contains(product.id) ||
                              (scope == 'category' &&
                                  categoryIds.contains(product.categoryId)),
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
                                markDirty();
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
                          lastDate: DateTime.now().add(
                            const Duration(days: 1825),
                          ),
                          initialDate: endDate,
                        );
                        if (date != null) {
                          setState(() {
                            markDirty();
                            endDate = date.add(
                              const Duration(hours: 23, minutes: 59),
                            );
                          });
                        }
                      },
                    ),
                    if (saveError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          saveError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : cancel,
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final percentage = double.tryParse(
                            discount.text.replaceAll(',', '.'),
                          );
                          final validSelection =
                              scope == 'all' ||
                              (scope == 'category' && categoryIds.isNotEmpty) ||
                              (scope == 'manual' && selected.isNotEmpty);
                          setState(() {
                            nameError = name.text.trim().isEmpty
                                ? 'Escriba el nombre de la promoción.'
                                : null;
                            discountError = percentage == null
                                ? 'Escriba un descuento numérico.'
                                : percentage <= 0 || percentage > 100
                                ? 'El descuento debe ser mayor que 0 y máximo 100.'
                                : null;
                            selectionError = validSelection
                                ? null
                                : scope == 'category'
                                ? 'Seleccione al menos una categoría.'
                                : 'Seleccione al menos un producto.';
                            saveError = null;
                          });
                          if (nameError != null ||
                              discountError != null ||
                              selectionError != null) {
                            return;
                          }

                          setState(() => saving = true);
                          try {
                            final promotion = BulkPromotion(
                              id: existing?.id ?? const Uuid().v4(),
                              name: name.text.trim(),
                              discountPercentage: percentage!,
                              conditionsText: conditions.text.trim(),
                              endDate: endDate,
                              appliesToAllProducts: scope == 'all',
                              isActive: existing?.isActive ?? true,
                            );
                            final allowedConditionIds = products
                                .where(
                                  (product) =>
                                      scope == 'all' ||
                                      (scope == 'manual' &&
                                          selected.contains(product.id)) ||
                                      (scope == 'category' &&
                                          categoryIds.contains(
                                            product.categoryId,
                                          )),
                                )
                                .map((product) => product.id)
                                .toSet();
                            final savedProductConditions = {
                              for (final entry in productConditions.entries)
                                if (allowedConditionIds.contains(entry.key) &&
                                    entry.value.trim().isNotEmpty)
                                  entry.key: entry.value.trim(),
                            };
                            final repository = ref.read(
                              promotionRepositoryProvider,
                            );
                            if (existing == null) {
                              await repository.createPromotion(
                                promotion,
                                productIds: scope == 'manual'
                                    ? selected
                                    : const <String>{},
                                categoryIds: scope == 'category'
                                    ? categoryIds
                                    : const <String>{},
                                productConditions: savedProductConditions,
                              );
                            } else {
                              await repository.updatePromotion(
                                promotion,
                                productIds: scope == 'manual'
                                    ? selected
                                    : const <String>{},
                                categoryIds: scope == 'category'
                                    ? categoryIds
                                    : const <String>{},
                                productConditions: savedProductConditions,
                              );
                            }
                            if (context.mounted) Navigator.pop(context, true);
                          } catch (error) {
                            setState(() {
                              saving = false;
                              saveError =
                                  'No fue posible guardar la promoción: $error';
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(existing == null ? 'Crear' : 'Guardar cambios'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (accepted == true) {
      ref.invalidate(promotionsProvider);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      discount.dispose();
      conditions.dispose();
    });
  }
}
