import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/return_api.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/utilities/search_query.dart';
import '../../../../shared/widgets/document_list_controls.dart';
import '../../../../shared/widgets/list_kpi_strip.dart';

class ReturnsPage extends ConsumerStatefulWidget {
  const ReturnsPage({super.key});

  @override
  ConsumerState<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends ConsumerState<ReturnsPage> {
  final _search = TextEditingController();
  String _status = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          final query = effectiveSearchQuery(_search.text).toLowerCase();
          final filtered = returns.where((item) {
            if (_status != 'ALL' && item.status.name != _status) return false;
            if (query.isEmpty) return true;
            return [
              item.returnNumber,
              item.customerName,
              item.status.name,
              item.reason,
              item.notes ?? '',
              item.currencyCode,
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
                int count(ReturnStatus status) =>
                    returns.where((item) => item.status == status).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DocumentListControls(
                    searchController: _search,
                    searchLabel: 'Buscar devoluciones',
                    searchHint: 'Número, cliente, motivo, producto o SKU',
                    onSearchChanged: (_) => setState(() {}),
                    statusValue: _status,
                    statusOptions: [
                      (value: 'ALL', label: 'Todos los estados'),
                      for (final status in ReturnStatus.values)
                        (value: status.name, label: _returnStatusLabel(status)),
                    ],
                    onStatusChanged: (value) => setState(() => _status = value),
                    kpis: [
                      ListKpi(
                        label: 'Total',
                        value: returns.length,
                        icon: Icons.assignment_return_outlined,
                      ),
                      ListKpi(
                        label: 'Borradores',
                        value: count(ReturnStatus.draft),
                        icon: Icons.edit_note_outlined,
                      ),
                      ListKpi(
                        label: 'Confirmadas',
                        value: count(ReturnStatus.confirmed),
                        icon: Icons.fact_check_outlined,
                      ),
                      ListKpi(
                        label: 'Canceladas',
                        value: count(ReturnStatus.cancelled),
                        icon: Icons.cancel_outlined,
                      ),
                    ],
                    resultCount: filtered.length,
                    totalCount: returns.length,
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
                    child: Text('No hay devoluciones para esos criterios.'),
                  ),
                );
              }
              final returnItem = filtered[index - 1];
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

  String _returnStatusLabel(ReturnStatus status) => switch (status) {
    ReturnStatus.draft => 'Borrador',
    ReturnStatus.confirmed => 'Confirmada',
    ReturnStatus.cancelled => 'Cancelada',
  };
}
