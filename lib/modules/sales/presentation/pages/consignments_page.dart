import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/consignment_api.dart';
import '../../../../shared/widgets/status_chip.dart';

class ConsignmentsPage extends ConsumerWidget {
  const ConsignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consignmentsAsync = ref.watch(consignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Consignaciones')),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/sales/consignments/new'),
            icon: const Icon(Icons.add),
            label: const Text('Nueva consignación'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: consignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (consignments) {
          if (consignments.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 40),
                  const SizedBox(height: 12),
                  const Text('No hay consignaciones registradas.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.go('/sales/consignments/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear consignación'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: consignments.length,
            itemBuilder: (context, index) {
              final consignment = consignments[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => context.go(
                    '/sales/consignments/${consignment.id}?returnTo=${Uri.encodeComponent('/sales/consignments')}',
                  ),
                  title: Text(consignment.consignmentNumber),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(consignment.customerName),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${consignment.currencyCode} ${consignment.totalAmount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          StatusChip(
                            label: switch (consignment.status) {
                              ConsignmentStatus.draft => 'Borrador',
                              ConsignmentStatus.sent => 'Enviada',
                              ConsignmentStatus.partialReturn => 'Parcial',
                              ConsignmentStatus.returned => 'Devuelta',
                              ConsignmentStatus.settled => 'Liquidada',
                              ConsignmentStatus.cancelled => 'Cancelada',
                            },
                            tone: switch (consignment.status) {
                              ConsignmentStatus.settled => StatusTone.success,
                              ConsignmentStatus.cancelled => StatusTone.danger,
                              ConsignmentStatus.returned => StatusTone.info,
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
                      if (consignment.status == ConsignmentStatus.sent ||
                          consignment.status == ConsignmentStatus.partialReturn)
                        IconButton(
                          tooltip: 'Registrar devolución parcial',
                          onPressed: () =>
                              _registerReturn(context, ref, consignment.id),
                          icon: const Icon(Icons.assignment_return_outlined),
                        ),
                      const Icon(Icons.chevron_right),
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

  Future<void> _registerReturn(
    BuildContext context,
    WidgetRef ref,
    String consignmentId,
  ) async {
    try {
      final document = await ref
          .read(consignmentApiProvider)
          .getConsignmentById(consignmentId);
      if (document == null || !context.mounted) return;
      final eligibleLines = document.lines
          .where((line) => line.quantity > line.returnedQuantity)
          .toList();
      if (eligibleLines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay cantidades pendientes de devolución.'),
          ),
        );
        return;
      }
      final selected = await showDialog<({String productId, int quantity})>(
        context: context,
        builder: (dialogContext) =>
            _ConsignmentReturnDialog(lines: eligibleLines),
      );
      if (selected == null || !context.mounted) return;
      await ref
          .read(consignmentApiProvider)
          .registerReturn(
            consignmentId: consignmentId,
            productId: selected.productId,
            quantity: selected.quantity,
          );
      ref.invalidate(consignmentsProvider);
      ref.invalidate(consignmentByIdProvider(consignmentId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo registrar la devolución: $error')),
        );
      }
    }
  }
}

class _ConsignmentReturnDialog extends StatefulWidget {
  const _ConsignmentReturnDialog({required this.lines});
  final List<SalesConsignmentLineDto> lines;

  @override
  State<_ConsignmentReturnDialog> createState() =>
      _ConsignmentReturnDialogState();
}

class _ConsignmentReturnDialogState extends State<_ConsignmentReturnDialog> {
  SalesConsignmentLineDto? _line;
  final _quantity = TextEditingController(text: '1');

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = _line;
    final maximum = line == null ? 0 : line.quantity - line.returnedQuantity;
    return AlertDialog(
      title: const Text('Registrar devolución'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<SalesConsignmentLineDto>(
            initialValue: _line,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Producto *'),
            items: [
              for (final item in widget.lines)
                DropdownMenuItem(
                  value: item,
                  child: Text(
                    '${item.productSku ?? ''} · ${item.productName ?? item.productId}',
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              _line = value;
              _quantity.text = '1';
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Cantidad (máximo $maximum)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              line == null ||
                  (int.tryParse(_quantity.text) ?? 0) < 1 ||
                  (int.tryParse(_quantity.text) ?? 0) > maximum
              ? null
              : () => Navigator.pop(context, (
                  productId: line.productId,
                  quantity: int.parse(_quantity.text),
                )),
          child: const Text('Registrar'),
        ),
      ],
    );
  }
}
