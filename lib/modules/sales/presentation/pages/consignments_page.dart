import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/consignment_api.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/utilities/search_query.dart';
import '../../../../shared/widgets/document_list_controls.dart';
import '../../../../shared/widgets/list_kpi_strip.dart';

class ConsignmentsPage extends ConsumerStatefulWidget {
  const ConsignmentsPage({super.key});

  @override
  ConsumerState<ConsignmentsPage> createState() => _ConsignmentsPageState();
}

class _ConsignmentsPageState extends ConsumerState<ConsignmentsPage> {
  final _search = TextEditingController();
  String _status = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          final query = effectiveSearchQuery(_search.text).toLowerCase();
          final filtered = consignments.where((item) {
            if (_status != 'ALL' && item.status.name != _status) return false;
            if (query.isEmpty) return true;
            return [
              item.consignmentNumber,
              item.customerName,
              item.status.name,
              item.currencyCode,
              item.notes ?? '',
              ...item.lines.expand(
                (line) => [line.productName ?? '', line.productSku ?? ''],
              ),
            ].join(' ').toLowerCase().contains(query);
          }).toList();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                int count(ConsignmentStatus status) =>
                    consignments.where((item) => item.status == status).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DocumentListControls(
                    searchController: _search,
                    searchLabel: 'Buscar consignaciones',
                    searchHint: 'Número, cliente, producto o SKU',
                    onSearchChanged: (_) => setState(() {}),
                    statusValue: _status,
                    statusOptions: [
                      (value: 'ALL', label: 'Todos los estados'),
                      for (final status in ConsignmentStatus.values)
                        (
                          value: status.name,
                          label: _consignmentStatusLabel(status),
                        ),
                    ],
                    onStatusChanged: (value) => setState(() => _status = value),
                    kpis: [
                      ListKpi(
                        label: 'Total',
                        value: consignments.length,
                        icon: Icons.inventory_2_outlined,
                      ),
                      ListKpi(
                        label: 'Enviadas',
                        value: count(ConsignmentStatus.sent),
                        icon: Icons.outbox_outlined,
                      ),
                      ListKpi(
                        label: 'Devolución parcial',
                        value: count(ConsignmentStatus.partialReturn),
                        icon: Icons.assignment_return_outlined,
                      ),
                      ListKpi(
                        label: 'Pendientes',
                        value:
                            count(ConsignmentStatus.sent) +
                            count(ConsignmentStatus.partialReturn) +
                            count(ConsignmentStatus.returned),
                        icon: Icons.pending_actions_outlined,
                      ),
                    ],
                    resultCount: filtered.length,
                    totalCount: consignments.length,
                    onClear: () => setState(() {
                      _search.clear();
                      _status = 'ALL';
                    }),
                  ),
                );
              }
              if (filtered.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay consignaciones para esos criterios.'),
                  ),
                );
              }
              final consignment = filtered[index - 1];
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

  String _consignmentStatusLabel(ConsignmentStatus status) => switch (status) {
    ConsignmentStatus.draft => 'Borrador',
    ConsignmentStatus.sent => 'Enviada',
    ConsignmentStatus.partialReturn => 'Parcial',
    ConsignmentStatus.returned => 'Devuelta',
    ConsignmentStatus.settled => 'Liquidada',
    ConsignmentStatus.cancelled => 'Cancelada',
  };

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
