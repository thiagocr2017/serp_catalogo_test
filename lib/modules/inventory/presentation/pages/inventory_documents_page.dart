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

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({required this.document});

  final InventoryDocumentDto document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          if (document.status == 'BORRADOR')
            _DraftActions(
              onConfirm: () => _confirmDraft(context, ref),
              onDispatch: document.type == InventoryDocumentType.transfer
                  ? () => _dispatchDraft(context, ref)
                  : null,
              documentType: document.type,
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDraft(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(inventoryApiProvider).confirmDocument(document.id);
      ref.invalidate(inventoryDocumentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Documento confirmado')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible confirmar: $error')),
        );
      }
    }
  }

  Future<void> _dispatchDraft(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(inventoryApiProvider).dispatchDocument(document.id);
      ref.invalidate(inventoryDocumentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Documento despachado')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible despachar: $error')),
        );
      }
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

class _DraftActions extends StatelessWidget {
  const _DraftActions({
    required this.onConfirm,
    this.onDispatch,
    required this.documentType,
  });

  final VoidCallback onConfirm;
  final VoidCallback? onDispatch;
  final InventoryDocumentType documentType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Confirmar'),
          ),
          if (onDispatch != null) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onDispatch,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Despachar'),
            ),
          ],
        ],
      ),
    );
  }
}
