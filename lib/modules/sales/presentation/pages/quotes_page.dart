import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/customer_summary_dtos.dart';
import '../../api/quote_api.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/utilities/search_query.dart';
import '../../../../shared/widgets/document_list_controls.dart';
import '../../../../shared/widgets/list_kpi_strip.dart';

class QuotesPage extends ConsumerStatefulWidget {
  const QuotesPage({super.key});

  @override
  ConsumerState<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends ConsumerState<QuotesPage> {
  final _searchController = TextEditingController();
  String _query = '';
  QuoteStatus? _status;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(quotesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Cotizaciones')),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/sales/quotes/new'),
            icon: const Icon(Icons.add),
            label: const Text('Nueva cotización'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: quotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (quotes) {
          if (quotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.request_quote_outlined, size: 40),
                  const SizedBox(height: 12),
                  const Text('No hay cotizaciones registradas.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.go('/sales/quotes/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear cotización'),
                  ),
                ],
              ),
            );
          }
          final normalizedQuery = effectiveSearchQuery(_query).toLowerCase();
          final filteredQuotes = quotes.where((quote) {
            if (_status != null && quote.status != _status) return false;
            if (normalizedQuery.isEmpty) return true;
            final searchable = [
              quote.quoteNumber,
              quote.customerName,
              quote.status.name,
              _statusLabel(quote.status),
              quote.currencyCode,
              quote.notes ?? '',
              for (final line in quote.lines) ...[
                line.productName ?? '',
                line.productSku ?? '',
                line.presentationName ?? '',
              ],
            ].join(' ').toLowerCase();
            return searchable.contains(normalizedQuery);
          }).toList();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: filteredQuotes.isEmpty ? 2 : filteredQuotes.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DocumentListControls(
                    searchController: _searchController,
                    searchLabel: 'Buscar cotizaciones',
                    searchHint: 'Número, cliente, producto o SKU',
                    onSearchChanged: (value) => setState(() => _query = value),
                    statusValue: _status?.name ?? 'ALL',
                    statusOptions: [
                      (value: 'ALL', label: 'Todos los estados'),
                      for (final status in QuoteStatus.values)
                        (value: status.name, label: _statusLabel(status)),
                    ],
                    onStatusChanged: (value) => setState(() {
                      _status = value == 'ALL'
                          ? null
                          : QuoteStatus.values.byName(value);
                    }),
                    kpis: [
                      ListKpi(
                        label: 'Total',
                        value: quotes.length,
                        icon: Icons.request_quote_outlined,
                      ),
                      ListKpi(
                        label: 'Borradores',
                        value: quotes
                            .where((q) => q.status == QuoteStatus.draft)
                            .length,
                        icon: Icons.edit_note_outlined,
                      ),
                      ListKpi(
                        label: 'Pendientes',
                        value: quotes
                            .where((q) => q.status == QuoteStatus.sent)
                            .length,
                        icon: Icons.outgoing_mail,
                      ),
                      ListKpi(
                        label: 'Aceptadas',
                        value: quotes
                            .where((q) => q.status == QuoteStatus.accepted)
                            .length,
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                    resultCount: filteredQuotes.length,
                    totalCount: quotes.length,
                    onClear: () => setState(() {
                      _searchController.clear();
                      _query = '';
                      _status = null;
                    }),
                  ),
                );
              }
              if (filteredQuotes.isEmpty && index == 1) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No hay cotizaciones para esos criterios.'),
                  ),
                );
              }
              final quote = filteredQuotes[index - 1];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  isThreeLine: true,
                  onTap: () => context.go(
                    '/sales/quotes/${quote.id}?returnTo=${Uri.encodeComponent('/sales/quotes')}',
                  ),
                  title: Text(quote.quoteNumber),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(quote.customerName),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${quote.currencyCode} ${quote.totalAmount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          StatusChip(
                            label: _statusLabel(quote.status),
                            tone: switch (quote.status) {
                              QuoteStatus.accepted => StatusTone.success,
                              QuoteStatus.rejected => StatusTone.danger,
                              QuoteStatus.expired => StatusTone.warning,
                              QuoteStatus.converted => StatusTone.info,
                              _ => StatusTone.neutral,
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing:
                      quote.status == QuoteStatus.draft ||
                          quote.status == QuoteStatus.sent
                      ? PopupMenuButton<QuoteStatus>(
                          tooltip: 'Cambiar estado',
                          onSelected: (status) async {
                            try {
                              await ref
                                  .read(quoteApiProvider)
                                  .updateQuoteStatus(quote.id, status);
                              ref.invalidate(quotesProvider);
                              if (quote.customerId != null) {
                                ref.invalidate(
                                  customerCommercialSummaryProvider(
                                    quote.customerId!,
                                  ),
                                );
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo cambiar el estado: $error',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            if (quote.status == QuoteStatus.draft)
                              const PopupMenuItem(
                                value: QuoteStatus.sent,
                                child: Text('Marcar enviada'),
                              ),
                            const PopupMenuItem(
                              value: QuoteStatus.accepted,
                              child: Text('Aceptar'),
                            ),
                            const PopupMenuItem(
                              value: QuoteStatus.rejected,
                              child: Text('Rechazar'),
                            ),
                          ],
                        )
                      : const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _statusLabel(QuoteStatus status) => switch (status) {
    QuoteStatus.draft => 'Borrador',
    QuoteStatus.sent => 'Enviada',
    QuoteStatus.accepted => 'Aceptada',
    QuoteStatus.rejected => 'Rechazada',
    QuoteStatus.expired => 'Expirada',
    QuoteStatus.converted => 'Convertida',
  };
}
