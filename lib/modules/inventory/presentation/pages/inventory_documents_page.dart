import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// Pantalla del propio módulo: importa sus capas directamente. El índice
// inventory_module.dart es la superficie para OTROS módulos.
import 'package:serp/modules/inventory/api/inventory_api.dart';
import 'package:serp/modules/inventory/di/inventory_providers.dart';

import '../../../../shared/widgets/status_chip.dart';

class InventoryDocumentsPage extends ConsumerWidget {
  const InventoryDocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(inventoryDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documentos de inventario')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/inventory/documents/new'),
        icon: const Icon(Icons.description_outlined),
        label: const Text('Nuevo documento'),
      ),
      body: documentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No fue posible cargar: $e')),
        data: (documents) {
          if (documents.isEmpty) {
            return const Center(child: Text('No hay documentos registrados.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              return _DocumentTile(document: doc);
            },
          );
        },
      ),
    );
  }
}

class _DocumentTile extends ConsumerStatefulWidget {
  const _DocumentTile({required this.document});

  final InventoryDocumentDto document;

  @override
  ConsumerState<_DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends ConsumerState<_DocumentTile> {
  bool _saving = false;

  InventoryDocumentDto get document => widget.document;

  String? get _actionLabel {
    if (document.type == InventoryDocumentType.transfer) {
      return switch (document.status) {
        'BORRADOR' => 'Despachar traslado',
        'DESPACHADA' => 'Marcar en tránsito',
        'EN_TRANSITO' => 'Registrar recepción',
        _ => null,
      };
    }
    return document.status == 'BORRADOR' ? 'Confirmar documento' : null;
  }

  IconData get _actionIcon => switch (document.status) {
    'BORRADOR' => Icons.local_shipping_outlined,
    'DESPACHADA' => Icons.directions_bus_outlined,
    'EN_TRANSITO' => Icons.inventory_2_outlined,
    _ => Icons.check_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    final actionLabel = _actionLabel;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            title: Text(document.number),
            subtitle: Text(
              '${_typeLabel(document.type)} \u00b7 ${document.status}',
            ),
            trailing: StatusChip(
              label: document.status,
              tone: _statusTone(document.status),
            ),
            onTap: () => context.go('/inventory/documents/${document.id}'),
          ),
          if (actionLabel != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _runTransition(context),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_actionIcon),
                    label: Text(actionLabel),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runTransition(BuildContext context) async {
    setState(() => _saving = true);
    try {
      final api = ref.read(inventoryApiProvider);
      final successMessage = switch (document.status) {
        'BORRADOR' when document.type == InventoryDocumentType.transfer =>
          () async {
            await api.dispatchTransfer(document.id);
            return 'Traslado despachado';
          },
        'BORRADOR' => () async {
          await api.confirmDocument(document.id);
          return 'Documento confirmado';
        },
        'DESPACHADA' => () async {
          await api.markTransferInTransit(document.id);
          return 'Traslado marcado en tránsito';
        },
        'EN_TRANSITO' => () async {
          await api.receiveTransfer(document.id);
          return 'Recepción del traslado registrada';
        },
        _ => null,
      };
      if (successMessage == null) return;
      final message = await successMessage();
      ref.invalidate(inventoryDocumentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible completar la acción: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _typeLabel(InventoryDocumentType type) => switch (type) {
    InventoryDocumentType.opening => 'Apertura',
    InventoryDocumentType.adjustment => 'Ajuste',
    InventoryDocumentType.transfer => 'Traslado',
    InventoryDocumentType.purchaseReceipt => 'Recepción',
    InventoryDocumentType.saleDispatch => 'Despacho venta',
    InventoryDocumentType.customerReturn => 'Dev. cliente',
    InventoryDocumentType.supplierReturn => 'Dev. proveedor',
    InventoryDocumentType.consignment => 'Consignación',
  };

  StatusTone _statusTone(String status) => switch (status) {
    'BORRADOR' => StatusTone.neutral,
    'DRAFT' => StatusTone.neutral,
    'CONFIRMED' => StatusTone.success,
    'CANCELLED' => StatusTone.danger,
    'DESPACHADA' => StatusTone.info,
    'EN_TRANSITO' => StatusTone.warning,
    'RECIBIDA' => StatusTone.success,
    _ => StatusTone.neutral,
  };
}
