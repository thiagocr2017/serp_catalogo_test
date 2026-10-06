import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/return_api.dart';
import '../../../../shared/widgets/status_chip.dart';

class ReturnsPage extends ConsumerWidget {
  const ReturnsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(returnsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Devoluciones')),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/sales/returns/new'),
            icon: const Icon(Icons.add),
            label: const Text('Nueva devolución'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: returnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (returns) {
          if (returns.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.assignment_return_outlined, size: 40),
                  const SizedBox(height: 12),
                  const Text('No hay devoluciones registradas.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.go('/sales/returns/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear devolución'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: returns.length,
            itemBuilder: (context, index) {
              final returnItem = returns[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => context.go(
                    '/sales/returns/${returnItem.id}?returnTo=${Uri.encodeComponent('/sales/returns')}',
                  ),
                  title: Text(returnItem.returnNumber),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(returnItem.customerName),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${returnItem.currencyCode} ${returnItem.totalAmount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          StatusChip(
                            label: switch (returnItem.status) {
                              ReturnStatus.draft => 'Borrador',
                              ReturnStatus.confirmed => 'Confirmada',
                              ReturnStatus.cancelled => 'Cancelada',
                            },
                            tone: switch (returnItem.status) {
                              ReturnStatus.confirmed => StatusTone.success,
                              ReturnStatus.cancelled => StatusTone.danger,
                              _ => StatusTone.neutral,
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
