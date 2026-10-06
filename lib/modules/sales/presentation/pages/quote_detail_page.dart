import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/status_chip.dart';
import '../../api/customer_summary_dtos.dart';
import '../../api/quote_api.dart';

class QuoteDetailPage extends ConsumerWidget {
  const QuoteDetailPage({required this.quoteId, this.returnTo, super.key});

  final String quoteId;
  final String? returnTo;

  String _safeReturn(String? value) {
    if (value == '/sales/quotes') return value!;
    if (value != null && RegExp(r'^/sales/customers/[^/]+$').hasMatch(value)) {
      return value;
    }
    return '/sales/quotes';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final back = _safeReturn(returnTo);
    final quoteAsync = ref.watch(quoteByIdProvider(quoteId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('quote-detail-back'),
          tooltip: back.startsWith('/sales/customers/')
              ? 'Volver al cliente'
              : 'Volver a cotizaciones',
          onPressed: () => context.go(back),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Detalle de cotización'),
        actions: [
          if (quoteAsync.asData?.value?.status == QuoteStatus.draft)
            IconButton(
              tooltip: 'Editar cotización',
              onPressed: () => context.go(
                Uri(
                  path: '/sales/quotes/$quoteId/edit',
                  queryParameters: {
                    'returnTo': Uri(
                      path: '/sales/quotes/$quoteId',
                      queryParameters: {
                        if (back != '/sales/quotes') 'returnTo': back,
                      },
                    ).toString(),
                  },
                ).toString(),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: quoteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No se pudo cargar la cotización: $error')),
        data: (quote) => quote == null
            ? const Center(child: Text('La cotización no existe.'))
            : _QuoteDetailContent(quote: quote, ref: ref, returnTo: back),
      ),
    );
  }
}

class _QuoteDetailContent extends StatelessWidget {
  const _QuoteDetailContent({
    required this.quote,
    required this.ref,
    required this.returnTo,
  });

  final SalesQuoteDto quote;
  final WidgetRef ref;
  final String returnTo;

  String get _status => switch (quote.status) {
    QuoteStatus.draft => 'Borrador',
    QuoteStatus.sent => 'Enviada',
    QuoteStatus.accepted => 'Aceptada',
    QuoteStatus.rejected => 'Rechazada',
    QuoteStatus.expired => 'Expirada',
    QuoteStatus.converted => 'Convertida',
  };

  Future<void> _changeStatus(BuildContext context, QuoteStatus status) async {
    try {
      await ref.read(quoteApiProvider).updateQuoteStatus(quote.id, status);
      ref.invalidate(quotesProvider);
      ref.invalidate(quoteByIdProvider(quote.id));
      if (quote.customerId != null) {
        ref.invalidate(customerCommercialSummaryProvider(quote.customerId!));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cambiar el estado: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quote.quoteNumber, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text('Creada ${_date(quote.createdAt)}'),
              ],
            ),
            StatusChip(
              label: _status,
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
        const SizedBox(height: 24),
        Text('Cliente', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Semantics(
              label: 'Cliente',
              child: CircleAvatar(child: Icon(Icons.person_outline)),
            ),
            title: Text(quote.customerName),
            subtitle: Text(
              quote.customerId == null
                  ? 'Cliente registrado en el documento'
                  : 'Ver perfil del cliente',
            ),
            trailing: quote.customerId == null
                ? null
                : Semantics(
                    label: 'Abrir perfil del cliente',
                    child: Icon(Icons.open_in_new),
                  ),
            onTap: quote.customerId == null
                ? null
                : () => context.go(
                    Uri(
                      path: '/sales/customers/${quote.customerId}',
                      queryParameters: {
                        'returnTo': Uri(
                          path: '/sales/quotes/${quote.id}',
                          queryParameters: {
                            if (returnTo != '/sales/quotes')
                              'returnTo': returnTo,
                          },
                        ).toString(),
                      },
                    ).toString(),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Productos cotizados', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (quote.lines.isEmpty)
          const ListTile(title: Text('El documento no tiene líneas guardadas.'))
        else
          for (final line in quote.lines)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.productName ?? 'Producto',
                                style: theme.textTheme.titleSmall,
                              ),
                              if (line.productSku?.isNotEmpty == true)
                                Text('SKU ${line.productSku}'),
                            ],
                          ),
                        ),
                        Text(
                          '${quote.currencyCode} ${line.totalPrice.toStringAsFixed(2)}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                    Text('Cantidad: ${line.quantity} unidades'),
                        Text(
                          'Precio unitario: ${quote.currencyCode} ${line.unitPrice.toStringAsFixed(2)}',
                        ),
                        Text(
                          'Descuento: ${line.discountPercent.toStringAsFixed(2)}%',
                        ),
                    if (line.unitsPerPresentation > 1)
                      Text(
                        '${line.quantity ~/ line.unitsPerPresentation} ${line.presentationName ?? 'presentaciones'} · ${line.unitsPerPresentation} unidades c/u',
                      ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (quote.validUntil != null)
                  ListTile(
                    dense: true,
                    title: const Text('Vigencia'),
                    trailing: Text(_date(quote.validUntil!)),
                  ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Total'),
                  titleTextStyle: theme.textTheme.titleLarge,
                  trailing: Text(
                    '${quote.currencyCode} ${quote.totalAmount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (quote.notes?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 20),
          Text('Notas', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(quote.notes!),
            ),
          ),
        ],
        if (quote.status == QuoteStatus.draft ||
            quote.status == QuoteStatus.sent) ...[
          const SizedBox(height: 24),
          Text('Acciones', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (quote.status == QuoteStatus.draft)
                OutlinedButton.icon(
                  onPressed: () => _changeStatus(context, QuoteStatus.sent),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Marcar enviada'),
                ),
              OutlinedButton.icon(
                onPressed: () => _changeStatus(context, QuoteStatus.accepted),
                icon: const Icon(Icons.check),
                label: const Text('Aceptar'),
              ),
              OutlinedButton.icon(
                onPressed: () => _changeStatus(context, QuoteStatus.rejected),
                icon: const Icon(Icons.close),
                label: const Text('Rechazar'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _date(DateTime? value) => value == null
      ? 'No disponible'
      : '${value.day}/${value.month}/${value.year}';
}
