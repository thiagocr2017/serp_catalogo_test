import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/order_api.dart';

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No hay pedidos registrados.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(order.orderNumber),
                  subtitle: Text(order.customerName),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${order.totalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Chip(
                        label: Text(switch (order.status) {
                          OrderStatus.draft => 'Borrador',
                          OrderStatus.confirmed => 'Confirmado',
                          OrderStatus.reserved => 'Reservado',
                          OrderStatus.dispatched => 'Despachado',
                          OrderStatus.delivered => 'Entregado',
                          OrderStatus.cancelled => 'Cancelado',
                        }),
                        backgroundColor: switch (order.status) {
                          OrderStatus.delivered => Colors.green.shade100,
                          OrderStatus.cancelled => Colors.red.shade100,
                          OrderStatus.dispatched => Colors.blue.shade100,
                          _ => Colors.grey.shade100,
                        },
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
