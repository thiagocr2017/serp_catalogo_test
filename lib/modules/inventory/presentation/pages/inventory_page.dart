import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/inventory_api.dart';
import '../../di/inventory_providers.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _search = TextEditingController();
  String _query = '';

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
          final filtered = items.where((item) {
            if (query.isEmpty) return true;
            return (item.productSku ?? '').toLowerCase().contains(query) ||
                _reason(item.reason).toLowerCase().contains(query) ||
                (item.documentNumber ?? '').toLowerCase().contains(query) ||
                (item.notes ?? '').toLowerCase().contains(query) ||
                item.quantity.toString().contains(query) ||
                item.createdAt.toLocal().toString().toLowerCase().contains(
                  query,
                );
          }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    labelText: 'Buscar movimientos',
                    hintText: 'Código, documento, motivo, cantidad o fecha',
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
                    ? const Center(child: Text('No hay movimientos.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.quantity > 0
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              child: Icon(
                                item.quantity > 0 ? Icons.add : Icons.remove,
                                color: item.quantity > 0
                                    ? Colors.green.shade900
                                    : Colors.red.shade900,
                              ),
                            ),
                            title: Text(
                              '${item.productSku ?? 'SKU no disponible'} · '
                              '${item.quantity > 0 ? '+' : ''}${item.quantity} · ${_reason(item.reason)}',
                            ),
                            subtitle: Text(
                              '${item.warehouseName ?? 'Bodega'} · '
                              '${item.locationName ?? 'Ubicación'}\n'
                              '${item.documentNumber ?? item.notes ?? 'Movimiento anterior'} · '
                              '${item.createdAt.toLocal()}',
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

  String _reason(InventoryReason value) => switch (value) {
    InventoryReason.initialStock => 'Stock inicial',
    InventoryReason.purchase => 'Compra',
    InventoryReason.sale => 'Venta',
    InventoryReason.adjustment => 'Ajuste',
    InventoryReason.returnItem => 'Devolución',
    InventoryReason.reversal => 'Reversión',
    InventoryReason.transferOut => 'Salida por traslado',
    InventoryReason.transferIn => 'Entrada por traslado',
  };
}
