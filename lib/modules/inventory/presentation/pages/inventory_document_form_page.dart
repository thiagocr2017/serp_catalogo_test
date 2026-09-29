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
  String? _destinationLocationId;
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
          _destinationLocationId ??= _defaultLocation(
            items,
            _destinationWarehouseId,
          )?.id;
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
        onChanged: (value) => setState(() {
          _destinationWarehouseId = value;
          _destinationLocationId = _defaultLocation(warehouses, value)?.id;
        }),
      ),
      const SizedBox(height: 12),
      _locationField(
        warehouses,
        warehouseId: _destinationWarehouseId,
        value: _destinationLocationId,
        label: _type == InventoryDocumentType.transfer
            ? 'Ubicación de destino'
            : 'Ubicación',
        onChanged: (value) => setState(() => _destinationLocationId = value),
      ),
      const SizedBox(height: 8),
      Text(
        _type == InventoryDocumentType.transfer
            ? 'El origen usa automáticamente su ubicación predeterminada. El destino puede elegirse.'
            : 'La ubicación predeterminada se propone automáticamente y puedes cambiarla.',
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
                  child: _productField(context, products, _lines[index]),
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

  Widget _locationField(
    List<Warehouse> warehouses, {
    required String? warehouseId,
    required String? value,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    final locations = warehouses
        .where((warehouse) => warehouse.id == warehouseId)
        .expand((warehouse) => warehouse.locations)
        .where((location) => location.isActive)
        .toList();
    return DropdownButtonFormField<String>(
      initialValue: locations.any((location) => location.id == value)
          ? value
          : null,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final location in locations)
          DropdownMenuItem(
            value: location.id,
            child: Text('${location.code} · ${location.name}'),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _productField(
    BuildContext context,
    List<Product> products,
    _DocumentLineDraft line,
  ) {
    final selected = products.where((product) => product.id == line.productId);
    final product = selected.isEmpty ? null : selected.first;
    return InkWell(
      onTap: () async {
        final value = await _pickProduct(context, products, line.productId);
        if (value != null) setState(() => line.productId = value);
      },
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Producto',
          prefixIcon: Icon(Icons.search),
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          product == null
              ? 'Buscar por código, nombre o descripción'
              : '${product.sku} · ${product.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<String?> _pickProduct(
    BuildContext context,
    List<Product> products,
    String? selectedId,
  ) async {
    final search = TextEditingController();
    var query = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final normalized = query.trim().toLowerCase();
          final filtered = products.where((product) {
            if (normalized.isEmpty) return true;
            return product.sku.toLowerCase().contains(normalized) ||
                product.name.toLowerCase().contains(normalized) ||
                product.description.toLowerCase().contains(normalized);
          }).toList();
          return AlertDialog(
            title: const Text('Buscar producto'),
            content: SizedBox(
              width: 680,
              height: 480,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    autofocus: true,
                    onChanged: (value) => setDialogState(() => query = value),
                    decoration: InputDecoration(
                      labelText: 'Código, nombre o descripción',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () {
                                search.clear();
                                setDialogState(() => query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No se encontraron productos.'),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return ListTile(
                                selected: item.id == selectedId,
                                title: Text('${item.sku} · ${item.name}'),
                                subtitle: Text(
                                  item.description.isEmpty
                                      ? 'Sin descripción'
                                      : item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text('Stock ${item.currentStock}'),
                                onTap: () => Navigator.pop(context, item.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );
    search.dispose();
    return result;
  }

  Warehouse? _defaultWarehouse(List<Warehouse> warehouses) {
    if (warehouses.isEmpty) return null;
    return warehouses.firstWhere(
      (warehouse) => warehouse.isDefault,
      orElse: () => warehouses.first,
    );
  }

  InventoryLocation? _defaultLocation(
    List<Warehouse> warehouses,
    String? warehouseId,
  ) {
    final matching = warehouses.where(
      (warehouse) => warehouse.id == warehouseId,
    );
    if (matching.isEmpty) return null;
    final locations = matching.first.locations
        .where((location) => location.isActive)
        .toList();
    if (locations.isEmpty) return null;
    return locations.firstWhere(
      (location) => location.isDefault,
      orElse: () => locations.first,
    );
  }

  Future<void> _save(BuildContext context) async {
    if (_destinationWarehouseId == null || _destinationLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la bodega y ubicación de destino.'),
        ),
      );
      return;
    }
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
              destinationLocationId: _destinationLocationId,
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
