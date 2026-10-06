import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/order_api.dart';
import '../../../../shared/widgets/status_chip.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({this.customerId, this.customerName, super.key});

  final String? customerId;
  final String? customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: customerId == null
            ? null
            : IconButton(
                tooltip: 'Volver al cliente',
                onPressed: () => context.go('/sales/customers/$customerId'),
                icon: const Icon(Icons.arrow_back),
              ),
        title: Semantics(
          header: true,
          child: Text(customerId == null ? 'Pedidos' : 'Pedidos del cliente'),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/sales/orders/new'),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo pedido'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          final visibleOrders = customerId == null
              ? orders
              : orders
                    .where(
                      (order) =>
                          order.customerId == customerId ||
                          (order.customerId == null &&
                              customerName != null &&
                              order.customerName.trim().toLowerCase() ==
                                  customerName!.trim().toLowerCase()),
                    )
                    .toList();
          if (visibleOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    orders.isEmpty
                        ? 'No hay pedidos registrados.'
                        : 'Este cliente no tiene pedidos registrados.',
                  ),
                  const SizedBox(height: 12),
                  if (customerId == null)
                    FilledButton.icon(
                      onPressed: () => context.go('/sales/orders/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear pedido'),
                    ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visibleOrders.length,
            itemBuilder: (context, index) {
              final order = visibleOrders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(order.orderNumber),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.customerName),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${order.currencyCode} ${order.totalAmount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          StatusChip(
                            label: switch (order.status) {
                              OrderStatus.draft => 'Borrador',
                              OrderStatus.confirmed => 'Confirmado',
                              OrderStatus.reserved => 'Reservado',
                              OrderStatus.dispatched => 'Despachado',
                              OrderStatus.delivered => 'Entregado',
                              OrderStatus.cancelled => 'Cancelado',
                            },
                            tone: switch (order.status) {
                              OrderStatus.delivered => StatusTone.success,
                              OrderStatus.cancelled => StatusTone.danger,
                              OrderStatus.dispatched => StatusTone.info,
                              _ => StatusTone.neutral,
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (order.status == OrderStatus.draft ||
                          order.status == OrderStatus.confirmed ||
                          order.status == OrderStatus.reserved)
                        IconButton(
                          tooltip: 'Cancelar pedido',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Cancelar pedido'),
                                content: Text(
                                  '¿Desea cancelar ${order.orderNumber}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Volver'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Cancelar pedido'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            try {
                              await ref
                                  .read(orderApiProvider)
                                  .cancelOrder(order.id);
                              ref.invalidate(ordersProvider);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo cancelar el pedido: $error',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.cancel_outlined),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
