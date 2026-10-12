import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/status_chip.dart';
import '../../api/customer_api.dart';
import '../../api/sales_invoice_api.dart';
import '../widgets/sales_document_detail_widgets.dart';

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
        (path != null && RegExp(r'^/sales/customers/[^/?]+$').hasMatch(path)) ||
        (path != null && RegExp(r'^/sales/returns/[^/?]+$').hasMatch(path))) {
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
          if (invoiceAsync.value?.status == SalesInvoiceStatus.confirmed ||
              invoiceAsync.value?.status == SalesInvoiceStatus.paid)
            FilledButton.icon(
              onPressed: () => context.go(
                '/sales/returns/new?invoiceId=${Uri.encodeQueryComponent(invoiceId)}&returnTo=${Uri.encodeQueryComponent(_safeReturnTo)}',
              ),
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('Iniciar devolución'),
            ),
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
          return _InvoiceDetailContent(invoice: invoice, ref: ref);
        },
      ),
    );
  }
}

class _InvoiceDetailContent extends StatelessWidget {
  const _InvoiceDetailContent({required this.invoice, required this.ref});

  final SalesInvoiceDto invoice;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SalesDocumentHeader(
          number: invoice.invoiceNumber,
          numberStyle: Theme.of(context).textTheme.headlineSmall,
          status: switch (invoice.status) {
            SalesInvoiceStatus.draft => 'Borrador',
            SalesInvoiceStatus.confirmed => 'Confirmada',
            SalesInvoiceStatus.cancelled => 'Cancelada',
            SalesInvoiceStatus.paid => 'Pagada',
          },
          statusTone: switch (invoice.status) {
            SalesInvoiceStatus.confirmed ||
            SalesInvoiceStatus.paid => StatusTone.success,
            SalesInvoiceStatus.cancelled => StatusTone.danger,
            SalesInvoiceStatus.draft => StatusTone.neutral,
          },
          facts: [
            if (invoice.createdAt != null) 'Creada ${_date(invoice.createdAt)}',
            if (invoice.confirmedAt != null)
              'Confirmada ${_date(invoice.confirmedAt)}',
          ],
        ),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: const SalesDocumentSectionTitle('Cliente'),
        ),
        _CustomerCard(
          customerName: invoice.customerName,
          customerId: invoice.customerId,
          documentId: invoice.id,
          ref: ref,
        ),
        const SizedBox(height: 24),
        const SalesDocumentSectionTitle('Productos facturados'),
        if (invoice.lines.isEmpty)
          const ListTile(title: Text('La factura no tiene líneas.'))
        else
          for (final line in invoice.lines)
            SalesDocumentLineCard(
              productName: line.productName ?? line.productSku ?? 'Producto',
              productSku: line.productSku,
              quantityLabel: 'Cantidad: ${line.quantity} unidades',
              unitPrice: line.unitPrice,
              currencyCode: invoice.currencyCode,
              total: line.totalPrice,
              discountPercent: line.discountPercent,
            ),
        const SizedBox(height: 12),
        SalesDocumentTotalCard(
          amount: invoice.totalAmount,
          currencyCode: invoice.currencyCode,
          additionalAmounts: {
            if (invoice.debtReductionAmount > 0)
              'Aplicado al saldo pendiente': invoice.debtReductionAmount,
            if (invoice.financialResolution != null &&
                invoice.financialResolutionAmount > 0)
              (invoice.financialResolution == 'REFUND'
                      ? 'Reembolso registrado'
                      : 'Crédito registrado'):
                  invoice.financialResolutionAmount,
          },
        ),
        if (invoice.inventoryDocumentId != null) ...[
          const SizedBox(height: 24),
          const SalesDocumentSectionTitle('Inventario'),
          _ReferenceTile(
            icon: Icons.inventory_2_outlined,
            title: 'Documento relacionado',
            value: invoice.inventoryDocumentId!,
          ),
        ],
        if (invoice.notes?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 24),
          const SalesDocumentSectionTitle('Notas'),
          _NotesCard(invoice.notes!),
        ],
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customerName,
    required this.customerId,
    required this.documentId,
    required this.ref,
  });

  final String customerName;
  final String? customerId;
  final String documentId;
  final WidgetRef ref;

  void _open(BuildContext context, String id) => context.go(
    '/sales/customers/$id?returnTo=${Uri.encodeQueryComponent('/sales/invoices/$documentId')}',
  );

  @override
  Widget build(BuildContext context) {
    if (customerId != null) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(customerName),
          subtitle: const Text('Abrir perfil del cliente'),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => _open(context, customerId!),
        ),
      );
    }
    return FutureBuilder<List<CustomerDto>>(
      future: ref.read(customerApiProvider).getCustomers(),
      builder: (context, snapshot) {
        final customer = snapshot.data
            ?.where(
              (item) =>
                  item.name.trim().toLowerCase() ==
                  customerName.trim().toLowerCase(),
            )
            .firstOrNull;
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(customerName),
            subtitle: Text(
              customer == null
                  ? 'Cliente registrado en el documento'
                  : 'Abrir perfil del cliente',
            ),
            trailing: customer == null ? null : const Icon(Icons.open_in_new),
            onTap: customer == null ? null : () => _open(context, customer.id),
          ),
        );
      },
    );
  }
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: SelectableText(value),
    ),
  );
}

class _NotesCard extends StatelessWidget {
  const _NotesCard(this.notes);

  final String notes;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(16), child: Text(notes)),
  );
}

String _date(DateTime? value) => value == null
    ? 'No disponible'
    : '${value.day}/${value.month}/${value.year}';
