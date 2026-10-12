import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/inventory_api.dart';
import '../../di/inventory_providers.dart';
import '../../../../shared/utilities/search_query.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key, this.productId, this.productSku});

  final String? productId;
  final String? productSku;

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final sku = widget.productSku?.trim();
    if (widget.productId != null && sku != null && sku.isNotEmpty) {
      _search.text = sku;
      _query = sku;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(inventoryTransactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de inventario')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/inventory/documents/new'),
        icon: const Icon(Icons.description_outlined),
        label: const Text('Nuevo documento'),
      ),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No fue posible cargar: $error')),
        data: (items) {
          final query = _query.trim().toLowerCase();
          final productId = widget.productId;
          final prefilledSku = widget.productSku?.trim().toLowerCase();
          final filtered = items.where((item) {
            if (productId != null && item.productId != productId) return false;
            if (query.isEmpty) return true;
            return (prefilledSku != null && query == prefilledSku) ||
                (item.productSku ?? '').toLowerCase().contains(query) ||
                describeInventoryTransaction(
                  item,
                  items,
                ).toLowerCase().contains(query) ||
                (item.warehouseName ?? '').toLowerCase().contains(query) ||
                (item.locationName ?? '').toLowerCase().contains(query) ||
                (item.documentNumber ?? '').toLowerCase().contains(query) ||
                (item.notes ?? '').toLowerCase().contains(query) ||
                item.quantity.toString().contains(query) ||
                item.createdAt.toLocal().toString().toLowerCase().contains(
                  query,
                );
          }).toList()..sort(compareInventoryHistory);
          return Column(
            children: [
              if (productId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Chip(
                        avatar: const Icon(Icons.filter_alt_outlined, size: 16),
                        label: Text(
                          widget.productSku?.trim().isNotEmpty == true
                              ? 'Movimientos de ${widget.productSku!.trim()}'
                              : 'Movimientos de un solo producto',
                        ),
                        onDeleted: () => context.go('/inventory'),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        onPressed: () => context.go('/products/$productId'),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Ver ficha del producto'),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (value) =>
                      setState(() => _query = effectiveSearchQuery(value)),
                  decoration: InputDecoration(
                    labelText: 'Buscar movimientos',
                    hintText: 'Código, documento, motivo, cantidad o fecha',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
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
                    ? Center(
                        child: Text(
                          productId == null
                              ? 'No hay movimientos.'
                              : 'No hay movimientos para este producto.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final colors = Theme.of(context).colorScheme;
                          final description = describeInventoryTransaction(
                            item,
                            items,
                          );
                          final notes = item.notes?.trim();
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.outlineVariant,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  item.quantity > 0 ? Icons.add : Icons.remove,
                                  color: colors.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                            ),
                            title: Text(
                              '${item.productSku ?? 'SKU no disponible'} · '
                              '${item.quantity > 0 ? '+' : ''}${item.quantity} · $description',
                            ),
                            subtitle: Text(
                              [
                                if (item.documentNumber?.trim().isNotEmpty ==
                                    true)
                                  'Doc. ${item.documentNumber!.trim()}',
                                if (notes != null && notes.isNotEmpty) notes,
                                '${item.createdAt.toLocal()}',
                              ].join(' · '),
                            ),
                            isThreeLine: true,
                            trailing: item.documentId == null
                                ? null
                                : TextButton.icon(
                                    onPressed: () => context.go(
                                      '/inventory/documents/${item.documentId}',
                                    ),
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Ir al documento'),
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
