import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/consignment_api.dart';

class ConsignmentsPage extends ConsumerWidget {
  const ConsignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consignmentsAsync = ref.watch(consignmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Consignaciones')),
      body: consignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (consignments) {
          if (consignments.isEmpty) {
            return const Center(child: Text('No hay consignaciones registradas.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: consignments.length,
            itemBuilder: (context, index) {
              final consignment = consignments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(consignment.consignmentNumber),
                  subtitle: Text(consignment.customerName),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${consignment.totalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Chip(
                        label: Text(switch (consignment.status) {
                          ConsignmentStatus.draft => 'Borrador',
                          ConsignmentStatus.sent => 'Enviada',
                          ConsignmentStatus.partialReturn => 'Parcial',
                          ConsignmentStatus.returned => 'Devuelta',
                          ConsignmentStatus.settled => 'Liquidada',
                          ConsignmentStatus.cancelled => 'Cancelada',
                        }),
                        backgroundColor: switch (consignment.status) {
                          ConsignmentStatus.settled => Colors.green.shade100,
                          ConsignmentStatus.cancelled => Colors.red.shade100,
                          ConsignmentStatus.returned => Colors.blue.shade100,
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
