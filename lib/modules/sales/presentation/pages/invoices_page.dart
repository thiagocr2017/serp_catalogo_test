import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/sales_invoice_api.dart';

class InvoicesPage extends ConsumerWidget {
  const InvoicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(salesInvoicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Facturas de Venta')),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (invoices) {
          if (invoices.isEmpty) {
            return const Center(
              child: Text('No hay facturas registradas.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(invoice.invoiceNumber),
                  subtitle: Text(invoice.customerName),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${invoice.totalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Chip(
                        label: Text(
                          switch (invoice.status) {
                            SalesInvoiceStatus.draft => 'Borrador',
                            SalesInvoiceStatus.confirmed => 'Confirmada',
                            SalesInvoiceStatus.cancelled => 'Cancelada',
                            SalesInvoiceStatus.paid => 'Pagada',
                          },
                        ),
                        backgroundColor: switch (invoice.status) {
                          SalesInvoiceStatus.confirmed => Colors.green.shade100,
                          SalesInvoiceStatus.cancelled => Colors.red.shade100,
                          SalesInvoiceStatus.paid => Colors.blue.shade100,
                          _ => Colors.grey.shade100,
                        },
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
}
