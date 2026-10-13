import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/sales_invoice_api.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../api/customer_summary_dtos.dart';
import '../../api/quote_api.dart';
import '../widgets/sales_document_detail_widgets.dart';

class QuoteDetailPage extends ConsumerWidget {
  const QuoteDetailPage({required this.quoteId, this.returnTo, super.key});

  final String quoteId;
  final String? returnTo;

  String _safeReturn(String? value) {
    if (value == '/sales/quotes') return value!;
    if (value != null && RegExp(r'^/sales/invoices/[^/?]+$').hasMatch(value)) {
      return value;
    }
    if (value != null && RegExp(r'^/sales/customers/[^/]+$').hasMatch(value)) {
      return value;
    }
    if (value != null) {
      final uri = Uri.tryParse(value);
      final nested = uri?.queryParameters['returnTo'];
      final validList =
          nested == '/sales/orders' ||
          (nested != null &&
              Uri.tryParse(nested)?.path == '/sales/orders' &&
              Uri.parse(nested).queryParameters.keys.every(
                (key) => key == 'customerId' || key == 'customerName',
              ));
      if (uri?.path.startsWith('/sales/orders/') == true && validList) {
        return uri.toString();
      }
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
      if (status == QuoteStatus.accepted && context.mounted) {
        await _createDraftInvoice(context);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cambiar el estado: $error')),
        );
      }
    }
  }

  Future<void> _createDraftInvoice(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cotización aceptada'),
        content: const Text(
          'Puede continuar creando una factura borrador. No se descontará inventario hasta confirmar la factura.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Más tarde'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Crear factura borrador'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final invoiceId = await ref
          .read(quoteApiProvider)
          .createDraftInvoiceFromQuote(quote.id);
      if (!context.mounted) return;
      ref.invalidate(quotesProvider);
      ref.invalidate(quoteByIdProvider(quote.id));
      ref.invalidate(salesInvoicesProvider);
      if (quote.customerId != null) {
        ref.invalidate(customerCommercialSummaryProvider(quote.customerId!));
      }
      final quoteRoute = Uri(
        path: '/sales/quotes/${quote.id}',
        queryParameters: {
          if (returnTo != '/sales/quotes') 'returnTo': returnTo,
        },
      ).toString();
      context.go(
        Uri(
          path: '/sales/invoices/$invoiceId',
          queryParameters: {'returnTo': quoteRoute},
        ).toString(),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo crear la factura borrador: $error'),
          ),
        );
      }
    }
  }

  void _openConvertedInvoice(BuildContext context) {
    final invoiceId = quote.convertedInvoiceId;
    if (invoiceId == null) return;
    final quoteRoute = Uri(
      path: '/sales/quotes/${quote.id}',
      queryParameters: {if (returnTo != '/sales/quotes') 'returnTo': returnTo},
    ).toString();
    context.go(
      Uri(
        path: '/sales/invoices/$invoiceId',
        queryParameters: {'returnTo': quoteRoute},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SalesDocumentHeader(
          number: quote.quoteNumber,
          numberStyle: Theme.of(context).textTheme.headlineSmall,
          status: _status,
          statusTone: switch (quote.status) {
            QuoteStatus.accepted => StatusTone.success,
            QuoteStatus.rejected => StatusTone.danger,
            QuoteStatus.expired => StatusTone.warning,
            QuoteStatus.converted => StatusTone.info,
            _ => StatusTone.neutral,
          },
          facts: [
            if (quote.createdAt != null) 'Creada ${_date(quote.createdAt)}',
            if (quote.updatedAt != null && quote.updatedAt != quote.createdAt)
              'Actualizada ${_date(quote.updatedAt)}',
            if (quote.validUntil != null)
              'Vigente hasta ${_date(quote.validUntil)}',
          ],
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: const SalesDocumentSectionTitle('Cliente'),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(quote.customerName),
            subtitle: Text(
              quote.customerId == null
                  ? 'Cliente registrado en el documento'
                  : 'Ver perfil del cliente',
            ),
            trailing: quote.customerId == null
                ? null
                : const Icon(Icons.open_in_new),
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
        const SalesDocumentSectionTitle('Productos cotizados'),
        if (quote.lines.isEmpty)
          const ListTile(title: Text('El documento no tiene líneas guardadas.'))
        else
          for (final line in quote.lines)
            SalesDocumentLineCard(
              productName: line.productName ?? 'Producto',
              productSku: line.productSku,
              quantityLabel: 'Cantidad: ${line.quantity} unidades',
              unitPrice: line.unitPrice,
              currencyCode: quote.currencyCode,
              total: line.totalPrice,
              discountPercent: line.discountPercent,
              additionalDetails: line.unitsPerPresentation > 1
                  ? '${line.quantity ~/ line.unitsPerPresentation} ${line.presentationName ?? 'presentaciones'} · ${line.unitsPerPresentation} unidades c/u'
                  : null,
            ),
        const SizedBox(height: 12),
        SalesDocumentTotalCard(
          amount: quote.totalAmount,
          currencyCode: quote.currencyCode,
        ),
        if (quote.notes?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 24),
          const SalesDocumentSectionTitle('Notas'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(quote.notes!),
            ),
          ),
        ],
        if (quote.status == QuoteStatus.draft ||
            quote.status == QuoteStatus.sent ||
            quote.status == QuoteStatus.accepted ||
            (quote.status == QuoteStatus.converted &&
                quote.convertedInvoiceId != null)) ...[
          const SizedBox(height: 24),
          const SalesDocumentSectionTitle('Acciones'),
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
              if (quote.status == QuoteStatus.draft ||
                  quote.status == QuoteStatus.sent) ...[
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
              if (quote.status == QuoteStatus.accepted)
                FilledButton.icon(
                  onPressed: () => _createDraftInvoice(context),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Crear factura borrador'),
                ),
              if (quote.status == QuoteStatus.converted &&
                  quote.convertedInvoiceId != null)
                FilledButton.icon(
                  onPressed: () => _openConvertedInvoice(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir factura borrador'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

String _date(DateTime? value) => value == null
    ? 'No disponible'
    : '${value.day}/${value.month}/${value.year}';
