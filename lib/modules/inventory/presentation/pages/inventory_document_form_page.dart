import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../product/product_module.dart';
import '../../api/inventory_api.dart';
import '../../di/inventory_providers.dart';

class InventoryDocumentFormPage extends ConsumerStatefulWidget {
  const InventoryDocumentFormPage({super.key});

  @override
  ConsumerState<InventoryDocumentFormPage> createState() =>
      _InventoryDocumentFormPageState();
}

class _InventoryDocumentFormPageState
    extends ConsumerState<InventoryDocumentFormPage> {
  InventoryDocumentType _type = InventoryDocumentType.adjustment;
  String? _originWarehouseId;
  String? _destinationWarehouseId;
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  final _lines = <_DocumentLineDraft>[_DocumentLineDraft()];
  bool _saving = false;

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = ref.watch(warehousesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo documento de inventario')),
      body: warehouses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No fue posible cargar: $error')),
        data: (items) {
          _destinationWarehouseId ??= _defaultWarehouse(items)?.id;
          _originWarehouseId ??= _defaultWarehouse(items)?.id;
          return FutureBuilder<List<Product>>(
            future: ref
                .read(productApiProvider)
                .getProducts(const ProductQuery(isActive: true)),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _content(context, items, snapshot.data!);
            },
          );
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    List<Warehouse> warehouses,
    List<Product> products,
  ) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      SegmentedButton<InventoryDocumentType>(
        segments: const [
          ButtonSegment(
            value: InventoryDocumentType.adjustment,
            icon: Icon(Icons.tune),
            label: Text('Ajuste'),
          ),
          ButtonSegment(
            value: InventoryDocumentType.transfer,
            icon: Icon(Icons.move_down),
            label: Text('Traslado'),
          ),
        ],
        selected: {_type},
        onSelectionChanged: (value) => setState(() => _type = value.single),
      ),
      const SizedBox(height: 20),
      if (_type == InventoryDocumentType.transfer) ...[
        _warehouseField(
          warehouses,
          label: 'Bodega de origen',
          value: _originWarehouseId,
          onChanged: (value) => setState(() => _originWarehouseId = value),
        ),
        const SizedBox(height: 12),
      ],
      _warehouseField(
        warehouses,
        label: _type == InventoryDocumentType.transfer
            ? 'Bodega de destino'
            : 'Bodega',
        value: _destinationWarehouseId,
        onChanged: (value) => setState(() => _destinationWarehouseId = value),
      ),
      const SizedBox(height: 8),
      Text(
        'La ubicación predeterminada de cada bodega se asignará automáticamente.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 20),
      TextField(
        controller: _reference,
        decoration: const InputDecoration(
          labelText: 'Referencia externa opcional',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _notes,
        decoration: const InputDecoration(labelText: 'Motivo u observaciones'),
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Text('Productos', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => setState(() => _lines.add(_DocumentLineDraft())),
            icon: const Icon(Icons.add),
            label: const Text('Agregar producto'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      for (var index = 0; index < _lines.length; index++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _lines[index].productId,
                    decoration: const InputDecoration(labelText: 'Producto'),
                    items: [
                      for (final product in products)
                        DropdownMenuItem(
                          value: product.id,
                          child: Text('${product.sku} · ${product.name}'),
                        ),
                    ],
                    onChanged: (value) => _lines[index].productId = value,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lines[index].quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      helperText: _type == InventoryDocumentType.adjustment
                          ? '+ suma / − resta'
                          : 'Cantidad a trasladar',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar línea',
                  onPressed: _lines.length == 1
                      ? null
                      : () => setState(() {
                          _lines.removeAt(index).dispose();
                        }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 24),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _saving ? null : () => _save(context),
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Confirmar documento'),
        ),
      ),
    ],
  );

  Widget _warehouseField(
    List<Warehouse> warehouses, {
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final warehouse in warehouses)
        DropdownMenuItem(
          value: warehouse.id,
          child: Text('${warehouse.code} · ${warehouse.name}'),
        ),
    ],
    onChanged: onChanged,
  );

  Warehouse? _defaultWarehouse(List<Warehouse> warehouses) {
    if (warehouses.isEmpty) return null;
    return warehouses.firstWhere(
      (warehouse) => warehouse.isDefault,
      orElse: () => warehouses.first,
    );
  }

  Future<void> _save(BuildContext context) async {
    final lines = <InventoryDocumentLineCommand>[];
    for (final draft in _lines) {
      final quantity = int.tryParse(draft.quantity.text.trim());
      if (draft.productId == null || quantity == null || quantity == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selecciona producto y cantidad en todas las líneas.',
            ),
          ),
        );
        return;
      }
      lines.add(
        InventoryDocumentLineCommand(
          productId: draft.productId!,
          quantity: _type == InventoryDocumentType.transfer
              ? quantity.abs()
              : quantity,
        ),
      );
    }
    if (_type == InventoryDocumentType.transfer &&
        _originWarehouseId == _destinationWarehouseId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona bodegas diferentes.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final document = await ref
          .read(inventoryApiProvider)
          .createAndConfirmDocument(
            InventoryDocumentCommand(
              commandId: const Uuid().v4(),
              type: _type,
              lines: lines,
              originWarehouseId: _type == InventoryDocumentType.transfer
                  ? _originWarehouseId
                  : null,
              destinationWarehouseId: _destinationWarehouseId,
              externalReference: _reference.text.trim(),
              notes: _notes.text.trim(),
            ),
          );
      ref.read(inventoryDataRevisionProvider.notifier).notifyChanged();
      ref.read(productDataRevisionProvider.notifier).notifyChanged();
      if (context.mounted) context.go('/inventory/documents/${document.id}');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible confirmar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DocumentLineDraft {
  String? productId;
  final quantity = TextEditingController();

  void dispose() => quantity.dispose();
}
