import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/order_api.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/utilities/search_query.dart';
import '../../../../shared/widgets/document_list_controls.dart';
import '../../../../shared/widgets/list_kpi_strip.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({this.customerId, this.customerName, super.key});

  final String? customerId;
  final String? customerName;

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> {
  final _search = TextEditingController();
  String _status = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: widget.customerId == null
            ? null
            : IconButton(
                tooltip: 'Volver al cliente',
                onPressed: () =>
                    context.go('/sales/customers/${widget.customerId}'),
                icon: const Icon(Icons.arrow_back),
              ),
        title: Semantics(
          header: true,
          child: Text(
            widget.customerId == null ? 'Pedidos' : 'Pedidos del cliente',
          ),
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/sales/orders/new'),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo pedido'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (orders) {
          final customerOrders = widget.customerId == null
              ? orders
              : orders
                    .where(
                      (order) =>
                          order.customerId == widget.customerId ||
                          (order.customerId == null &&
                              widget.customerName != null &&
                              order.customerName.trim().toLowerCase() ==
                                  widget.customerName!.trim().toLowerCase()),
                    )
                    .toList();
          final visibleOrders = customerOrders.where((order) {
            if (_status != 'ALL' && order.status.name != _status) return false;
            final query = effectiveSearchQuery(_search.text).toLowerCase();
            if (query.isEmpty) return true;
            return [
              order.orderNumber,
              order.customerName,
              order.status.name,
              order.notes ?? '',
              ...order.lines.expand(
                (line) => [line.productName ?? '', line.productSku ?? ''],
              ),
            ].join(' ').toLowerCase().contains(query);
          }).toList();
          if (customerOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    customerOrders.isEmpty
                        ? 'No hay pedidos registrados.'
                        : 'Este cliente no tiene pedidos registrados.',
                  ),
                  const SizedBox(height: 12),
                  if (widget.customerId == null)
                    FilledButton.icon(
                      onPressed: () => context.go('/sales/orders/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear pedido'),
                    ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: visibleOrders.isEmpty ? 2 : visibleOrders.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                int count(OrderStatus status) =>
                    customerOrders.where((o) => o.status == status).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DocumentListControls(
                    searchController: _search,
                    searchLabel: 'Buscar pedidos',
                    searchHint: 'Número, cliente, producto o SKU',
                    onSearchChanged: (_) => setState(() {}),
                    statusValue: _status,
                    statusOptions: [
                      (value: 'ALL', label: 'Todos los estados'),
                      for (final status in OrderStatus.values)
                        (value: status.name, label: _orderStatusLabel(status)),
                    ],
                    onStatusChanged: (value) => setState(() => _status = value),
                    kpis: [
                      ListKpi(
                        label: 'Total',
                        value: customerOrders.length,
                        icon: Icons.shopping_bag_outlined,
                      ),
                      ListKpi(
                        label: 'Borradores',
                        value: count(OrderStatus.draft),
                        icon: Icons.edit_note_outlined,
                      ),
                      ListKpi(
                        label: 'Activos',
                        value:
                            count(OrderStatus.confirmed) +
                            count(OrderStatus.reserved) +
                            count(OrderStatus.dispatched),
                        icon: Icons.local_shipping_outlined,
                      ),
                      ListKpi(
                        label: 'Entregados',
                        value: count(OrderStatus.delivered),
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                    resultCount: visibleOrders.length,
                    totalCount: customerOrders.length,
                    onClear: () => setState(() {
                      _search.clear();
                      _status = 'ALL';
                    }),
                  ),
                );
              }
              if (visibleOrders.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No hay pedidos para esos criterios.'),
                  ),
                );
              }
              final order = visibleOrders[index - 1];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(order.orderNumber),
                  onTap: () {
                    final listPath = widget.customerId == null
                        ? '/sales/orders'
                        : Uri(
                            path: '/sales/orders',
                            queryParameters: {
                              'customerId': widget.customerId!,
                              if (widget.customerName != null)
                                'customerName': widget.customerName!,
                            },
                          ).toString();
                    context.go(
                      '/sales/orders/${order.id}?returnTo=${Uri.encodeQueryComponent(listPath)}',
                    );
                  },
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.customerName),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${order.currencyCode} ${order.totalAmount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          StatusChip(
                            label: switch (order.status) {
                              OrderStatus.draft => 'Borrador',
                              OrderStatus.confirmed => 'Confirmado',
                              OrderStatus.reserved => 'Reservado',
                              OrderStatus.dispatched => 'Despachado',
                              OrderStatus.delivered => 'Entregado',
                              OrderStatus.cancelled => 'Cancelado',
                            },
                            tone: switch (order.status) {
                              OrderStatus.delivered => StatusTone.success,
                              OrderStatus.cancelled => StatusTone.danger,
                              OrderStatus.dispatched => StatusTone.info,
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
                      if (order.status == OrderStatus.draft ||
                          order.status == OrderStatus.confirmed ||
                          order.status == OrderStatus.reserved)
                        IconButton(
                          tooltip: 'Cancelar pedido',
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Cancelar pedido'),
                                content: Text(
                                  '¿Desea cancelar ${order.orderNumber}?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Volver'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Cancelar pedido'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            try {
                              await ref
                                  .read(orderApiProvider)
                                  .cancelOrder(order.id);
                              ref.invalidate(ordersProvider);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo cancelar el pedido: $error',
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

  String _orderStatusLabel(OrderStatus status) => switch (status) {
    OrderStatus.draft => 'Borrador',
    OrderStatus.confirmed => 'Confirmado',
    OrderStatus.reserved => 'Reservado',
    OrderStatus.dispatched => 'Despachado',
    OrderStatus.delivered => 'Entregado',
    OrderStatus.cancelled => 'Cancelado',
  };
}
