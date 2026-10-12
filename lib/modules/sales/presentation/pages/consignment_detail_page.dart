import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/status_chip.dart';
import '../../api/consignment_api.dart';
import '../widgets/sales_document_detail_widgets.dart';

class ConsignmentDetailPage extends ConsumerWidget {
  const ConsignmentDetailPage({
    required this.consignmentId,
    this.returnTo,
    super.key,
  });

  final String consignmentId;
  final String? returnTo;

  String get _safeReturnTo {
    final value = returnTo;
    if (value == '/sales/consignments' ||
        (value != null &&
            RegExp(r'^/sales/customers/[^/?]+$').hasMatch(value))) {
      return value!;
    }
    return '/sales/consignments';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(consignmentByIdProvider(consignmentId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a consignaciones',
          onPressed: () => context.go(_safeReturnTo),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Detalle de consignación'),
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No fue posible cargar: $error')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('La consignación no existe.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SalesDocumentHeader(
                number: item.consignmentNumber,
                numberStyle: Theme.of(context).textTheme.headlineSmall,
                status: switch (item.status) {
                  ConsignmentStatus.draft => 'Borrador',
                  ConsignmentStatus.sent => 'Enviada',
                  ConsignmentStatus.partialReturn => 'Devolución parcial',
                  ConsignmentStatus.returned => 'Devuelta',
                  ConsignmentStatus.settled => 'Liquidada',
                  ConsignmentStatus.cancelled => 'Cancelada',
                },
                statusTone: switch (item.status) {
                  ConsignmentStatus.settled => StatusTone.success,
                  ConsignmentStatus.cancelled => StatusTone.danger,
                  ConsignmentStatus.returned => StatusTone.info,
                  _ => StatusTone.neutral,
                },
                facts: [
                  if (item.createdAt != null) 'Creada ${_date(item.createdAt)}',
                  if (item.confirmedAt != null)
                    'Confirmada ${_date(item.confirmedAt)}',
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
                  title: Text(item.customerName),
                  subtitle: Text(
                    item.customerId == null
                        ? 'Cliente registrado en el documento'
                        : 'Abrir perfil del cliente',
                  ),
                  trailing: item.customerId == null
                      ? null
                      : const Icon(Icons.open_in_new),
                  onTap: item.customerId == null
                      ? null
                      : () => context.go(
                          '/sales/customers/${item.customerId}?returnTo=${Uri.encodeQueryComponent('/sales/consignments/$consignmentId')}',
                        ),
                ),
              ),
              const SizedBox(height: 24),
              const SalesDocumentSectionTitle('Productos consignados'),
              if (item.lines.isEmpty)
                const ListTile(title: Text('La consignación no tiene líneas.'))
              else
                for (final line in item.lines)
                  SalesDocumentLineCard(
                    productName:
                        line.productName ?? line.productSku ?? line.productId,
                    productSku: line.productSku,
                    quantityLabel: 'Enviados: ${line.quantity}',
                    unitPrice: line.unitPrice,
                    currencyCode: item.currencyCode,
                    total: line.totalPrice,
                    additionalDetails:
                        'Devueltos: ${line.returnedQuantity} · Pendientes de devolución: ${_pendingReturn(line.quantity, line.returnedQuantity)}',
                  ),
              const SizedBox(height: 12),
              SalesDocumentTotalCard(
                amount: item.totalAmount,
                currencyCode: item.currencyCode,
                label: 'Importe de origen',
                additionalAmounts: {'Importe devuelto': item.returnedAmount},
              ),
              if (item.inventoryDocumentId != null) ...[
                const SizedBox(height: 24),
                const SalesDocumentSectionTitle('Inventario'),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Documento relacionado'),
                    subtitle: SelectableText(item.inventoryDocumentId!),
                  ),
                ),
              ],
              if (item.notes?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 24),
                const SalesDocumentSectionTitle('Notas'),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(item.notes!),
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

String _date(DateTime? value) => value == null
    ? 'No disponible'
    : '${value.day}/${value.month}/${value.year}';

int _pendingReturn(int sent, int returned) => (sent - returned).clamp(0, sent);
