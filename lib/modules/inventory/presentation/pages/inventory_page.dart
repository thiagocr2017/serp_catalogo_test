import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../product/di/product_providers.dart';
import '../../../product/domain/entities/product_query.dart';
import '../../../product/presentation/controllers/product_list_controller.dart';
import '../../di/inventory_providers.dart';
import '../../domain/entities/inventory_transaction.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(inventoryTransactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos de inventario')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Registrar movimiento'),
      ),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No fue posible cargar: $e')),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: item.quantity > 0
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                child: Icon(item.quantity > 0 ? Icons.add : Icons.remove),
              ),
              title: Text(
                '${item.productSku ?? 'SKU no disponible'} · '
                '${item.quantity > 0 ? '+' : ''}${item.quantity} · ${_reason(item.reason)}',
              ),
              subtitle: Text(
                '${item.notes ?? 'Sin notas'}\n${item.createdAt.toLocal()}',
              ),
              isThreeLine: true,
              trailing:
                  item.reason == InventoryReason.reversal ||
                      item.reversalOfTransactionId != null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.undo),
                      tooltip: 'Corregir con reversión',
                      onPressed: () => _reverse(context, ref, item),
                    ),
            );
          },
        ),
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
  };

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final products = await ref.read(getProductsProvider)(
      const ProductQuery(isActive: true),
    );
    if (!context.mounted) return;
    String? productId = products.isEmpty ? null : products.first.id;
    var reason = InventoryReason.purchase;
    final quantity = TextEditingController();
    final notes = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Registrar movimiento'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: productId,
                  decoration: const InputDecoration(labelText: 'Producto'),
                  items: [
                    for (final p in products)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.sku} · ${p.name}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => productId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<InventoryReason>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                  items: const [
                    DropdownMenuItem(
                      value: InventoryReason.purchase,
                      child: Text('Compra/entrada'),
                    ),
                    DropdownMenuItem(
                      value: InventoryReason.sale,
                      child: Text('Venta/salida'),
                    ),
                    DropdownMenuItem(
                      value: InventoryReason.adjustment,
                      child: Text('Ajuste'),
                    ),
                    DropdownMenuItem(
                      value: InventoryReason.returnItem,
                      child: Text('Devolución'),
                    ),
                  ],
                  onChanged: (v) => setState(() => reason = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: reason == InventoryReason.adjustment
                        ? 'Cantidad con signo (ej. -5 o 5)'
                        : 'Cantidad',
                    helperText: switch (reason) {
                      InventoryReason.sale =>
                        'Se registrará automáticamente como salida negativa.',
                      InventoryReason.adjustment =>
                        'Usa signo negativo para restar o positivo para sumar.',
                      _ => 'Se registrará como entrada positiva.',
                    },
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    border: OutlineInputBorder(),
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
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && productId != null) {
      final entered = int.tryParse(quantity.text.trim());
      if (entered == null || entered == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ingresa una cantidad entera distinta de cero.'),
            ),
          );
        }
      } else {
        final signed = signedInventoryQuantity(
          enteredQuantity: entered,
          reason: reason,
        );
        try {
          await ref
              .read(inventoryRepositoryProvider)
              .addTransaction(
                productId: productId!,
                quantity: signed,
                reason: reason,
                notes: notes.text.trim(),
              );
          ref.invalidate(inventoryTransactionsProvider);
          ref.invalidate(productListControllerProvider);
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No fue posible registrar el movimiento: $error'),
              ),
            );
          }
        }
      }
    }
    quantity.dispose();
    notes.dispose();
  }

  Future<void> _reverse(
    BuildContext context,
    WidgetRef ref,
    InventoryTransaction item,
  ) async {
    final notes = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Corregir movimiento'),
        content: TextField(
          controller: notes,
          decoration: const InputDecoration(labelText: 'Motivo obligatorio'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear reversión'),
          ),
        ],
      ),
    );
    if (accepted == true && notes.text.trim().isNotEmpty) {
      await ref
          .read(inventoryRepositoryProvider)
          .reverseTransaction(item, notes: notes.text.trim());
      ref.invalidate(inventoryTransactionsProvider);
      ref.invalidate(productListControllerProvider);
    }
    notes.dispose();
  }
}
