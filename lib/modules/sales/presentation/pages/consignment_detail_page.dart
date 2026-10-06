import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/consignment_api.dart';
import '../../../../shared/widgets/status_chip.dart';

class ConsignmentDetailPage extends ConsumerWidget {
  const ConsignmentDetailPage({
    required this.consignmentId,
    this.returnTo,
    super.key,
  });

  final String consignmentId;
  final String? returnTo;

  String get _safeReturnTo =>
      returnTo == '/sales/consignments' ? returnTo! : '/sales/consignments';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(consignmentByIdProvider(consignmentId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a consignaciones',
          onPressed: () => context.go(_safeReturnTo),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Detalle de consignación'),
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No fue posible cargar: $error')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('La consignación no existe.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.consignmentNumber),
                subtitle: Text('Enviada: ${item.createdAt ?? 'Sin fecha'}'),
                trailing: StatusChip(
                  label: switch (item.status) {
                    ConsignmentStatus.draft => 'Borrador',
                    ConsignmentStatus.sent => 'Enviada',
                    ConsignmentStatus.partialReturn => 'Devolución parcial',
                    ConsignmentStatus.returned => 'Devuelta',
                    ConsignmentStatus.settled => 'Liquidada',
                    ConsignmentStatus.cancelled => 'Cancelada',
                  },
                  tone: switch (item.status) {
                    ConsignmentStatus.settled => StatusTone.success,
                    ConsignmentStatus.cancelled => StatusTone.danger,
                    ConsignmentStatus.returned => StatusTone.info,
                    _ => StatusTone.neutral,
                  },
                ),
              ),
              const Divider(),
              if (item.customerId != null)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(item.customerName),
                  subtitle: const Text('Cliente'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => context.go(
                    '/sales/customers/${item.customerId}?returnTo=${Uri.encodeComponent('/sales/consignments/$consignmentId')}',
                  ),
                )
              else
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(item.customerName),
                  subtitle: const Text('Cliente'),
                ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Importe de origen'),
                trailing: Text(
                  '${item.currencyCode} ${item.totalAmount.toStringAsFixed(2)}',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.assignment_return_outlined),
                title: const Text('Importe devuelto'),
                trailing: Text(
                  '${item.currencyCode} ${item.returnedAmount.toStringAsFixed(2)}',
                ),
              ),
              if (item.notes?.trim().isNotEmpty == true)
                ListTile(
                  title: const Text('Notas'),
                  subtitle: Text(item.notes!),
                ),
              const SizedBox(height: 16),
              Text(
                'Productos consignados',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final line in item.lines)
                ListTile(
                  title: Text(
                    line.productName ?? line.productSku ?? line.productId,
                  ),
                  subtitle: Text(
                    '${line.productSku ?? ''} · ${line.quantity} enviados · '
                    '${line.returnedQuantity} devueltos · '
                    '${item.currencyCode} ${line.unitPrice.toStringAsFixed(2)} c/u',
                  ),
                  trailing: Text(
                    '${item.currencyCode} ${line.totalPrice.toStringAsFixed(2)}',
                  ),
                ),
              if (item.inventoryDocumentId != null)
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Documento de inventario'),
                  subtitle: Text(item.inventoryDocumentId!),
                ),
            ],
          );
        },
      ),
    );
  }
}
