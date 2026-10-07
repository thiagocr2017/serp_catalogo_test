import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/return_api.dart';
import '../../../../shared/widgets/status_chip.dart';

class ReturnDetailPage extends ConsumerWidget {
  const ReturnDetailPage({required this.returnId, this.returnTo, super.key});

  final String returnId;
  final String? returnTo;

  String get _safeReturnTo =>
      returnTo == '/sales/returns' ? returnTo! : '/sales/returns';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(returnByIdProvider(returnId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a devoluciones',
          onPressed: () => context.go(_safeReturnTo),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Detalle de devolución'),
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No fue posible cargar: $error')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('La devolución no existe.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.returnNumber),
                subtitle: Text('Motivo: ${item.reason}'),
                trailing: StatusChip(
                  label: switch (item.status) {
                    ReturnStatus.draft => 'Borrador',
                    ReturnStatus.confirmed => 'Confirmada',
                    ReturnStatus.cancelled => 'Cancelada',
                  },
                  tone: switch (item.status) {
                    ReturnStatus.confirmed => StatusTone.success,
                    ReturnStatus.cancelled => StatusTone.danger,
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
                    '/sales/customers/${item.customerId}?returnTo=${Uri.encodeComponent('/sales/returns/$returnId')}',
                  ),
                )
              else
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(item.customerName),
                  subtitle: const Text('Cliente'),
                ),
              if (item.invoiceId != null)
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Abrir factura de origen'),
                  subtitle: Text(item.invoiceId!),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => context.go(
                    '/sales/invoices/${item.invoiceId}?returnTo=${Uri.encodeComponent('/sales/returns/$returnId')}',
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Total registrado'),
                trailing: Text(
                  '${item.currencyCode} ${item.totalAmount.toStringAsFixed(2)}',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Aplicado al saldo pendiente'),
                trailing: Text(
                  '${item.currencyCode} ${item.debtReductionAmount.toStringAsFixed(2)}',
                ),
              ),
              if (item.financialResolution != null)
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(
                    item.financialResolution == 'REFUND'
                        ? 'Reembolso'
                        : 'Crédito del cliente',
                  ),
                  trailing: Text(
                    '${item.currencyCode} ${item.financialResolutionAmount.toStringAsFixed(2)}',
                  ),
                ),
              if (item.notes?.trim().isNotEmpty == true)
                ListTile(
                  title: const Text('Notas'),
                  subtitle: Text(item.notes!),
                ),
              const SizedBox(height: 16),
              Text('Productos', style: Theme.of(context).textTheme.titleMedium),
              for (final line in item.lines)
                ListTile(
                  title: Text(
                    line.productName ?? line.productSku ?? line.productId,
                  ),
                  subtitle: Text(
                    '${line.productSku ?? ''} · ${line.quantity} devuelta · '
                    '${item.currencyCode} ${line.unitPrice.toStringAsFixed(2)} c/u · '
                    '${line.condition == 'DAMAGED' ? 'Dañado · cuarentena' : 'Buen estado · vendible'}',
                  ),
                  trailing: Text(
                    '${item.currencyCode} ${line.totalPrice.toStringAsFixed(2)}',
                  ),
                ),
              if (item.inventoryDocumentId != null)
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('Movimiento de inventario'),
                  subtitle: Text(item.inventoryDocumentId!),
                ),
            ],
          );
        },
      ),
    );
  }
}
