import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/sales_invoice_api.dart';
import '../../api/customer_api.dart';

class SalesInvoiceDetailPage extends ConsumerWidget {
  const SalesInvoiceDetailPage({
    required this.invoiceId,
    this.returnTo,
    super.key,
  });

  final String invoiceId;
  final String? returnTo;

  String get _safeReturnTo {
    final path = returnTo;
    if (path == '/sales/invoices' ||
        (path != null && RegExp(r'^/sales/customers/[^/?]+$').hasMatch(path))) {
      return path!;
    }
    return '/sales/invoices';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(salesInvoiceByIdProvider(invoiceId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a facturas',
          onPressed: () => context.go(_safeReturnTo),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Detalle de factura'),
        actions: [
          invoiceAsync.value?.status == SalesInvoiceStatus.confirmed ||
                  invoiceAsync.value?.status == SalesInvoiceStatus.paid
              ? FilledButton.icon(
                  onPressed: () => context.go(
                    '/sales/returns/new?invoiceId=${Uri.encodeQueryComponent(invoiceId)}&returnTo=${Uri.encodeQueryComponent(_safeReturnTo)}',
                  ),
                  icon: const Icon(Icons.assignment_return_outlined),
                  label: const Text('Iniciar devolución'),
                )
              : const SizedBox.shrink(),
          const SizedBox(width: 12),
        ],
      ),
      body: invoiceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No se pudo cargar la factura: $error')),
        data: (invoice) {
          if (invoice == null) {
            return const Center(child: Text('La factura no existe.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                invoice.invoiceNumber,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(invoice.customerName),
                  Chip(label: Text(_statusLabel(invoice.status))),
                  Text(
                    '${invoice.currencyCode} ${invoice.totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              if (invoice.customerId != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go(
                      '/sales/customers/${invoice.customerId}?returnTo=${Uri.encodeQueryComponent('/sales/invoices/$invoiceId')}',
                    ),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Ver perfil del cliente'),
                  ),
                ),
              ],
              if (invoice.customerId == null)
                FutureBuilder<List<CustomerDto>>(
                  future: ref.read(customerApiProvider).getCustomers(),
                  builder: (context, snapshot) {
                    final customer = snapshot.data
                        ?.where(
                          (item) =>
                              item.name.trim().toLowerCase() ==
                              invoice.customerName.trim().toLowerCase(),
                        )
                        .firstOrNull;
                    if (customer == null) return const SizedBox.shrink();
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.go(
                          '/sales/customers/${customer.id}?returnTo=${Uri.encodeQueryComponent('/sales/invoices/$invoiceId')}',
                        ),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Ver perfil del cliente'),
                      ),
                    );
                  },
                ),
              const Divider(height: 32),
              Text('Productos', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (invoice.lines.isEmpty)
                const ListTile(title: Text('La factura no tiene líneas.'))
              else
                for (final line in invoice.lines)
                  ListTile(
                    title: Text(
                      line.productName ?? line.productSku ?? 'Producto',
                    ),
                    subtitle: Text(
                      '${line.productSku ?? ''} · ${line.quantity} × ${invoice.currencyCode} ${line.unitPrice.toStringAsFixed(2)} · Descuento ${line.discountPercent.toStringAsFixed(2)}%',
                    ),
                    trailing: Text(
                      '${invoice.currencyCode} ${line.totalPrice.toStringAsFixed(2)}',
                    ),
                  ),
              if (invoice.notes?.trim().isNotEmpty == true)
                ListTile(
                  title: const Text('Notas'),
                  subtitle: Text(invoice.notes!),
                ),
            ],
          );
        },
      ),
    );
  }

  String _statusLabel(SalesInvoiceStatus status) => switch (status) {
    SalesInvoiceStatus.draft => 'Borrador',
    SalesInvoiceStatus.confirmed => 'Confirmada',
    SalesInvoiceStatus.cancelled => 'Cancelada',
    SalesInvoiceStatus.paid => 'Pagada',
  };
}
