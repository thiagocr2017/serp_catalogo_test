import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/return_api.dart';

class ReturnsPage extends ConsumerWidget {
  const ReturnsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(returnsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Devoluciones')),
      body: returnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (returns) {
          if (returns.isEmpty) {
            return const Center(child: Text('No hay devoluciones registradas.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: returns.length,
            itemBuilder: (context, index) {
              final returnItem = returns[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(returnItem.returnNumber),
                  subtitle: Text(returnItem.customerName),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${returnItem.totalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Chip(
                        label: Text(switch (returnItem.status) {
                          ReturnStatus.draft => 'Borrador',
                          ReturnStatus.confirmed => 'Confirmada',
                          ReturnStatus.cancelled => 'Cancelada',
                        }),
                        backgroundColor: switch (returnItem.status) {
                          ReturnStatus.confirmed => Colors.green.shade100,
                          ReturnStatus.cancelled => Colors.red.shade100,
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
