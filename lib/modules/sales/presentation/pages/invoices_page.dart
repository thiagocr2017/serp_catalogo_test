import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/sales_invoice_api.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/utilities/search_query.dart';
import '../../../../shared/widgets/document_list_controls.dart';
import '../../../../shared/widgets/list_kpi_strip.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  final _search = TextEditingController();
  String _status = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(salesInvoicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Facturas de Venta')),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/sales/invoices/new'),
            icon: const Icon(Icons.add),
            label: const Text('Nueva factura'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (invoices) {
          if (invoices.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 40),
                  const SizedBox(height: 12),
                  const Text('No hay facturas registradas.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.go('/sales/invoices/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear factura'),
                  ),
                ],
              ),
            );
          }
          final query = effectiveSearchQuery(_search.text).toLowerCase();
          final filtered = invoices.where((invoice) {
            if (_status != 'ALL' && invoice.status.name != _status) {
              return false;
            }
            if (query.isEmpty) return true;
            return [
              invoice.invoiceNumber,
              invoice.customerName,
              invoice.status.name,
              invoice.currencyCode,
              invoice.notes ?? '',
              ...invoice.lines.expand(
                (line) => [line.productName ?? '', line.productSku ?? ''],
              ),
            ].join(' ').toLowerCase().contains(query);
          }).toList();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                int count(SalesInvoiceStatus status) =>
                    invoices.where((item) => item.status == status).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DocumentListControls(
                    searchController: _search,
                    searchLabel: 'Buscar facturas',
                    searchHint: 'Número, cliente, producto o SKU',
                    onSearchChanged: (_) => setState(() {}),
                    statusValue: _status,
                    statusOptions: [
                      (value: 'ALL', label: 'Todos los estados'),
                      for (final status in SalesInvoiceStatus.values)
                        (
                          value: status.name,
                          label: _invoiceStatusLabel(status),
                        ),
                    ],
                    onStatusChanged: (value) => setState(() => _status = value),
                    kpis: [
                      ListKpi(
                        label: 'Total',
                        value: invoices.length,
                        icon: Icons.receipt_long_outlined,
                      ),
                      ListKpi(
                        label: 'Borradores',
                        value: count(SalesInvoiceStatus.draft),
                        icon: Icons.edit_note_outlined,
                      ),
                      ListKpi(
                        label: 'Confirmadas',
                        value: count(SalesInvoiceStatus.confirmed),
                        icon: Icons.fact_check_outlined,
                      ),
                      ListKpi(
                        label: 'Pagadas',
                        value: count(SalesInvoiceStatus.paid),
                        icon: Icons.payments_outlined,
                      ),
                    ],
                    resultCount: filtered.length,
                    totalCount: invoices.length,
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
                    child: Text('No hay facturas para esos criterios.'),
                  ),
                );
              }
              final invoice = filtered[index - 1];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => context.go(
                    '/sales/invoices/${invoice.id}?returnTo=${Uri.encodeQueryComponent('/sales/invoices')}',
                  ),
                  title: Text(invoice.invoiceNumber),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invoice.customerName),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${invoice.currencyCode} ${invoice.totalAmount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          StatusChip(
                            label: switch (invoice.status) {
                              SalesInvoiceStatus.draft => 'Borrador',
                              SalesInvoiceStatus.confirmed => 'Confirmada',
                              SalesInvoiceStatus.cancelled => 'Cancelada',
                              SalesInvoiceStatus.paid => 'Pagada',
                            },
                            tone: switch (invoice.status) {
                              SalesInvoiceStatus.confirmed =>
                                StatusTone.success,
                              SalesInvoiceStatus.cancelled => StatusTone.danger,
                              SalesInvoiceStatus.paid => StatusTone.info,
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
                      if (invoice.status == SalesInvoiceStatus.confirmed ||
                          invoice.status == SalesInvoiceStatus.paid)
                        IconButton(
                          tooltip: 'Iniciar devolución',
                          onPressed: () => context.go(
                            '/sales/returns/new?invoiceId=${Uri.encodeQueryComponent(invoice.id)}&returnTo=${Uri.encodeQueryComponent('/sales/invoices')}',
                          ),
                          icon: const Icon(Icons.assignment_return_outlined),
                        ),
                      if (invoice.status == SalesInvoiceStatus.confirmed)
                        IconButton(
                          tooltip: 'Cancelar factura',
                          onPressed: () async {
                            final reason = await showDialog<String>(
                              context: context,
                              builder: (dialogContext) => _CancelInvoiceDialog(
                                invoiceNumber: invoice.invoiceNumber,
                              ),
                            );
                            if (reason == null || !context.mounted) return;
                            try {
                              await ref
                                  .read(salesInvoiceApiProvider)
                                  .cancelInvoice(invoice.id, reason: reason);
                              ref.invalidate(salesInvoicesProvider);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo cancelar la factura: $error',
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

  String _invoiceStatusLabel(SalesInvoiceStatus status) => switch (status) {
    SalesInvoiceStatus.draft => 'Borrador',
    SalesInvoiceStatus.confirmed => 'Confirmada',
    SalesInvoiceStatus.cancelled => 'Cancelada',
    SalesInvoiceStatus.paid => 'Pagada',
  };
}

class _CancelInvoiceDialog extends StatefulWidget {
  const _CancelInvoiceDialog({required this.invoiceNumber});
  final String invoiceNumber;

  @override
  State<_CancelInvoiceDialog> createState() => _CancelInvoiceDialogState();
}

class _CancelInvoiceDialogState extends State<_CancelInvoiceDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Cancelar ${widget.invoiceNumber}'),
    content: TextField(
      controller: _reason,
      autofocus: true,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Motivo *',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Volver'),
      ),
      FilledButton(
        onPressed: () {
          if (_reason.text.trim().isNotEmpty) {
            Navigator.pop(context, _reason.text.trim());
          }
        },
        child: const Text('Cancelar factura'),
      ),
    ],
  );
}
