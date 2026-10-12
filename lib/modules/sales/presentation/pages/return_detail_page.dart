import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/status_chip.dart';
import '../../api/return_api.dart';
import '../widgets/sales_document_detail_widgets.dart';

class ReturnDetailPage extends ConsumerWidget {
  const ReturnDetailPage({required this.returnId, this.returnTo, super.key});

  final String returnId;
  final String? returnTo;

  String get _safeReturnTo {
    final value = returnTo;
    if (value == '/sales/returns' ||
        (value != null &&
            RegExp(r'^/sales/customers/[^/?]+$').hasMatch(value)) ||
        (value != null &&
            RegExp(r'^/sales/invoices/[^/?]+$').hasMatch(value))) {
      return value!;
    }
    return '/sales/returns';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(returnByIdProvider(returnId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a devoluciones',
          onPressed: () => context.go(_safeReturnTo),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Detalle de devolución'),
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No fue posible cargar: $error')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('La devolución no existe.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SalesDocumentHeader(
                number: item.returnNumber,
                numberStyle: Theme.of(context).textTheme.headlineSmall,
                status: switch (item.status) {
                  ReturnStatus.draft => 'Borrador',
                  ReturnStatus.confirmed => 'Confirmada',
                  ReturnStatus.cancelled => 'Cancelada',
                },
                statusTone: switch (item.status) {
                  ReturnStatus.confirmed => StatusTone.success,
                  ReturnStatus.cancelled => StatusTone.danger,
                  ReturnStatus.draft => StatusTone.neutral,
                },
                facts: [
                  'Motivo: ${item.reason}',
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
                          '/sales/customers/${item.customerId}?returnTo=${Uri.encodeQueryComponent('/sales/returns/$returnId')}',
                        ),
                ),
              ),
              if (item.invoiceId != null) ...[
                const SizedBox(height: 24),
                const SalesDocumentSectionTitle('Factura de origen'),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(item.invoiceId!),
                    subtitle: const Text('Abrir factura relacionada'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => context.go(
                      '/sales/invoices/${item.invoiceId}?returnTo=${Uri.encodeQueryComponent('/sales/returns/$returnId')}',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const SalesDocumentSectionTitle('Productos devueltos'),
              if (item.lines.isEmpty)
                const ListTile(title: Text('La devolución no tiene líneas.'))
              else
                for (final line in item.lines)
                  SalesDocumentLineCard(
                    productName:
                        line.productName ?? line.productSku ?? line.productId,
                    productSku: line.productSku,
                    quantityLabel: 'Cantidad devuelta: ${line.quantity}',
                    unitPrice: line.unitPrice,
                    currencyCode: item.currencyCode,
                    total: line.totalPrice,
                    additionalDetails: line.condition == 'DAMAGED'
                        ? 'Condición: dañada · destino: cuarentena${line.conditionNote?.trim().isNotEmpty == true ? ' · Nota: ${line.conditionNote!.trim()}' : ''}'
                        : 'Condición: buen estado · destino: vendible',
                  ),
              const SizedBox(height: 12),
              SalesDocumentTotalCard(
                amount: item.totalAmount,
                currencyCode: item.currencyCode,
                additionalAmounts: {
                  if (item.debtReductionAmount > 0)
                    'Aplicado al saldo pendiente': item.debtReductionAmount,
                  if (item.financialResolution != null &&
                      item.financialResolutionAmount > 0)
                    (item.financialResolution == 'REFUND'
                            ? 'Reembolso registrado'
                            : 'Crédito del cliente'):
                        item.financialResolutionAmount,
                },
              ),
              if (item.inventoryDocumentId != null) ...[
                const SizedBox(height: 24),
                const SalesDocumentSectionTitle('Inventario'),
                _ReferenceTile(value: item.inventoryDocumentId!),
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

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      leading: const Icon(Icons.inventory_2_outlined),
      title: const Text('Documento de inventario relacionado'),
      subtitle: SelectableText(value),
    ),
  );
}

String _date(DateTime? value) => value == null
    ? 'No disponible'
    : '${value.day}/${value.month}/${value.year}';
