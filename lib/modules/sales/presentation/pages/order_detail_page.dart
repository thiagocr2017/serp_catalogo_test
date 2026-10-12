import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/status_chip.dart';
import '../../api/order_api.dart';
import '../widgets/sales_document_detail_widgets.dart';

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({required this.orderId, this.returnTo, super.key});

  final String orderId;
  final String? returnTo;

  String get _safeReturnTo {
    final value = returnTo;
    if (value == '/sales/orders') return value!;
    if (value != null) {
      final candidates = <String>{value};
      try {
        candidates.add(Uri.decodeComponent(value));
      } on FormatException {
        // Invalid encoding falls back to the unfiltered index.
      }
      for (final candidate in candidates) {
        final uri = Uri.tryParse(candidate);
        if (uri?.path == '/sales/orders' &&
            uri!.queryParameters.keys.every(
              (key) => key == 'customerId' || key == 'customerName',
            )) {
          return uri.toString();
        }
      }
    }
    return '/sales/orders';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(orderByIdProvider(orderId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a pedidos',
          onPressed: () => context.go(_safeReturnTo),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Detalle de pedido'),
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No fue posible cargar: $error')),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('El pedido no existe.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SalesDocumentHeader(
                number: order.orderNumber,
                numberStyle: Theme.of(context).textTheme.headlineSmall,
                status: _statusLabel(order.status),
                statusTone: switch (order.status) {
                  OrderStatus.delivered => StatusTone.success,
                  OrderStatus.cancelled => StatusTone.danger,
                  OrderStatus.dispatched => StatusTone.info,
                  _ => StatusTone.neutral,
                },
                facts: [
                  if (order.createdAt != null)
                    'Creado ${_date(order.createdAt)}',
                  if (order.confirmedAt != null)
                    'Confirmado ${_date(order.confirmedAt)}',
                  if (order.cancelledAt != null)
                    'Cancelado ${_date(order.cancelledAt)}',
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
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(order.customerName),
                  subtitle: Text(
                    order.customerId == null
                        ? 'Cliente registrado en el documento'
                        : 'Abrir perfil del cliente',
                  ),
                  trailing: order.customerId == null
                      ? null
                      : const Icon(Icons.open_in_new),
                  onTap: order.customerId == null
                      ? null
                      : () => context.go(
                          '/sales/customers/${order.customerId}?returnTo=${Uri.encodeQueryComponent('/sales/orders/$orderId?returnTo=${Uri.encodeQueryComponent(_safeReturnTo)}')}',
                        ),
                ),
              ),
              if (order.quoteId != null) ...[
                const SizedBox(height: 24),
                const SalesDocumentSectionTitle('Cotización de origen'),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.request_quote_outlined),
                    title: Text(order.quoteId!),
                    subtitle: const Text('Abrir cotización relacionada'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => context.go(
                      '/sales/quotes/${order.quoteId}?returnTo=${Uri.encodeQueryComponent('/sales/orders/$orderId?returnTo=${Uri.encodeQueryComponent(_safeReturnTo)}')}',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const SalesDocumentSectionTitle('Productos del pedido'),
              if (order.lines.isEmpty)
                const ListTile(title: Text('El pedido no tiene líneas.'))
              else
                for (final line in order.lines)
                  SalesDocumentLineCard(
                    productName:
                        line.productName ?? line.productSku ?? 'Producto',
                    productSku: line.productSku,
                    quantityLabel: 'Cantidad: ${line.quantity} unidades',
                    unitPrice: line.unitPrice,
                    currencyCode: order.currencyCode,
                    total: line.totalPrice,
                    discountPercent: line.discountPercent,
                  ),
              const SizedBox(height: 12),
              SalesDocumentTotalCard(
                amount: order.totalAmount,
                currencyCode: order.currencyCode,
              ),
              if (order.inventoryDocumentId != null) ...[
                const SizedBox(height: 24),
                const SalesDocumentSectionTitle('Inventario'),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Documento relacionado'),
                    subtitle: SelectableText(order.inventoryDocumentId!),
                  ),
                ),
              ],
              if (order.notes?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 24),
                const SalesDocumentSectionTitle('Notas'),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(order.notes!),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _statusLabel(OrderStatus status) => switch (status) {
  OrderStatus.draft => 'Borrador',
  OrderStatus.confirmed => 'Confirmado',
  OrderStatus.reserved => 'Reservado',
  OrderStatus.dispatched => 'Despachado',
  OrderStatus.delivered => 'Entregado',
  OrderStatus.cancelled => 'Cancelado',
};

String _date(DateTime? value) => value == null
    ? 'No disponible'
    : '${value.day}/${value.month}/${value.year}';
