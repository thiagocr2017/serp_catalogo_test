import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/inventory_api.dart';

class InventoryDocumentPage extends ConsumerWidget {
  const InventoryDocumentPage({required this.documentId, super.key});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Volver a documentos',
        onPressed: () => context.go('/inventory/documents'),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Documento de inventario'),
    ),
    body: FutureBuilder<InventoryDocumentDto?>(
      future: ref.read(inventoryApiProvider).getDocument(documentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final document = snapshot.data;
        if (document == null) {
          return const Center(child: Text('El documento no existe.'));
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              document.number,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text('${_typeLabel(document.type)} · ${document.status}'),
            if (document.originWarehouseName != null)
              Text(
                'Origen: ${document.originWarehouseName} / ${document.originLocationName}',
              ),
            if (document.destinationWarehouseName != null)
              Text(
                'Destino: ${document.destinationWarehouseName} / ${document.destinationLocationName}',
              ),
            if (document.notes?.isNotEmpty == true) Text(document.notes!),
            const SizedBox(height: 24),
            Text('Productos', style: Theme.of(context).textTheme.titleLarge),
            for (final line in document.lines)
              ListTile(
                title: Text(
                  '${line.productSku ?? ''} · ${line.productName ?? ''}',
                ),
                subtitle: Text('Cantidad: ${line.quantity}'),
                trailing: IconButton(
                  tooltip: 'Ir al producto',
                  onPressed: () => context.go('/products/${line.productId}'),
                  icon: const Icon(Icons.open_in_new),
                ),
              ),
          ],
        );
      },
    ),
  );

  String _typeLabel(InventoryDocumentType type) => switch (type) {
    InventoryDocumentType.opening => 'Apertura de inventario',
    InventoryDocumentType.adjustment => 'Ajuste',
    InventoryDocumentType.transfer => 'Traslado',
    InventoryDocumentType.purchaseReceipt => 'Recepción de compra',
    InventoryDocumentType.saleDispatch => 'Despacho de venta',
    InventoryDocumentType.customerReturn => 'Devolución de cliente',
    InventoryDocumentType.supplierReturn => 'Devolución a proveedor',
    InventoryDocumentType.consignment => 'Consignación',
  };
}
