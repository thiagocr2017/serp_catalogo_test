import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/promotion_providers.dart';
import '../../../../shared/utilities/search_query.dart';

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
        onPressed: () => context.go('/promotions/new'),
        icon: const Icon(Icons.add),
        label: const Text('Nueva promoción'),
      ),
      body: promotions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No fue posible cargar: $e')),
        data: (items) {
          final query = effectiveSearchQuery(_query).toLowerCase();
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
                                  onPressed: () =>
                                      context.go('/promotions/${p.id}/edit'),
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
}
