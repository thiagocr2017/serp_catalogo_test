import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/navigation/unsaved_changes_guard.dart';
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
  String? _originLocationId;
  String? _destinationWarehouseId;
  String? _destinationLocationId;
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  final _lines = <_DocumentLineDraft>[_DocumentLineDraft()];
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _reference.addListener(_markDirty);
    _notes.addListener(_markDirty);
  }

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
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await UnsavedChangesGuard.instance.confirmNavigation(context) &&
            mounted) {
          _markClean();
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Nuevo documento de inventario')),
        body: warehouses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('No fue posible cargar: $error')),
          data: (items) {
            _ensureDefaults(items);
            return FutureBuilder<List<dynamic>>(
              future: Future.wait([
                ref
                    .read(productApiProvider)
                    .listProducts(const ProductListQuery(isActive: true)),
                ref.read(inventoryApiProvider).getLocationBalances(),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _content(
                  context,
                  items,
                  snapshot.data![0] as List<ProductSummaryDto>,
                  snapshot.data![1] as List<InventoryBalanceDto>,
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _markDirty() {
    if (_saving) return;
    _dirty = true;
    UnsavedChangesGuard.instance.markDirty();
  }

  void _markClean() {
    _dirty = false;
    UnsavedChangesGuard.instance.markClean();
  }

  /// Propone valores iniciales sin pisar lo que el usuario ya eligió.
  void _ensureDefaults(List<WarehouseDto> warehouses) {
    _destinationWarehouseId ??= _defaultWarehouse(warehouses)?.id;
    _originWarehouseId ??= _defaultWarehouse(warehouses)?.id;
    _destinationLocationId ??= _defaultLocation(
      warehouses,
      _destinationWarehouseId,
    )?.id;
    _originLocationId ??= _defaultLocation(warehouses, _originWarehouseId)?.id;
  }

  Widget _content(
    BuildContext context,
    List<WarehouseDto> warehouses,
    List<ProductSummaryDto> products,
    List<InventoryBalanceDto> balances,
  ) {
    final isTransfer = _type == InventoryDocumentType.transfer;
    final availability = <String, int>{
      for (final balance in balances)
        if (balance.locationId == _originLocationId)
          balance.productId: balance.quantity,
    };
    final movementError = isTransfer ? _movementError() : null;
    final lineErrors = [
      for (final line in _lines)
        _lineError(line, isTransfer: isTransfer, availability: availability),
    ];
    final canSave =
        !_saving &&
        movementError == null &&
        _lines.isNotEmpty &&
        !lineErrors.any((error) => error != null) &&
        _lines.every(
          (line) =>
              line.productId != null &&
              int.tryParse(line.quantity.text.trim()) != null &&
              int.parse(line.quantity.text.trim()) != 0,
        );
    final totalUnits = _lines.fold<int>(
      0,
      (total, line) =>
          total + (int.tryParse(line.quantity.text.trim())?.abs() ?? 0),
    );

    return ListView(
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
          onSelectionChanged: (value) => setState(() {
            _type = value.single;
            _markDirty();
          }),
        ),
        const SizedBox(height: 20),
        if (isTransfer)
          _movementCard(context, warehouses, movementError)
        else
          _adjustmentCard(context, warehouses),
        const SizedBox(height: 12),
        TextField(
          controller: _reference,
          decoration: const InputDecoration(
            labelText: 'Referencia externa opcional',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(
            labelText: 'Motivo u observaciones',
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Productos', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _addLine,
              icon: const Icon(Icons.add),
              label: const Text('Agregar producto'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < _lines.length; index++)
          _lineCard(
            context,
            products,
            index,
            lineError: lineErrors[index],
            available: isTransfer && _lines[index].productId != null
                ? availability[_lines[index].productId]
                : null,
            isTransfer: isTransfer,
          ),
        const SizedBox(height: 8),
        Text(
          '${_lines.length} ${_lines.length == 1 ? 'línea' : 'líneas'} · $totalUnits ${totalUnits == 1 ? 'unidad' : 'unidades'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_type == InventoryDocumentType.transfer)
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _save(context, draft: true),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar como borrador'),
              ),
            if (_type == InventoryDocumentType.transfer)
              const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: canSave ? () => _save(context) : null,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _type == InventoryDocumentType.transfer
                    ? 'Confirmar traslado'
                    : 'Confirmar ajuste',
              ),
            ),
          ],
        ),
        if (!canSave && !_saving)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                movementError ??
                    'Completa productos y cantidades para continuar.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.right,
              ),
            ),
          ),
      ],
    );
  }

  /// Tarjeta Desde → Hacia con botón para intercambiar el sentido.
  /// La misma bodega está permitida: lo que debe diferir es la ubicación.
  Widget _movementCard(
    BuildContext context,
    List<WarehouseDto> warehouses,
    String? movementError,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _endpointColumn(
                    context,
                    title: 'Desde',
                    icon: Icons.upload,
                    warehouseLabel: 'Bodega de origen',
                    locationLabel: 'Ubicación de origen',
                    warehouseId: _originWarehouseId,
                    locationId: _originLocationId,
                    warehouses: warehouses,
                    onWarehouseChanged: (value) => setState(() {
                      _originWarehouseId = value;
                      _originLocationId = _defaultLocation(
                        warehouses,
                        value,
                      )?.id;
                      _markDirty();
                    }),
                    onLocationChanged: (value) => setState(() {
                      _originLocationId = value;
                      _markDirty();
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 40, left: 4, right: 4),
                  child: IconButton.filledTonal(
                    tooltip: 'Intercambiar origen y destino',
                    onPressed: () => setState(() {
                      final warehouseId = _originWarehouseId;
                      final locationId = _originLocationId;
                      _originWarehouseId = _destinationWarehouseId;
                      _originLocationId = _destinationLocationId;
                      _destinationWarehouseId = warehouseId;
                      _destinationLocationId = locationId;
                      _markDirty();
                    }),
                    icon: const Icon(Icons.swap_horiz),
                  ),
                ),
                Expanded(
                  child: _endpointColumn(
                    context,
                    title: 'Hacia',
                    icon: Icons.download,
                    warehouseLabel: 'Bodega de destino',
                    locationLabel: 'Ubicación de destino',
                    warehouseId: _destinationWarehouseId,
                    locationId: _destinationLocationId,
                    warehouses: warehouses,
                    onWarehouseChanged: (value) => setState(() {
                      _destinationWarehouseId = value;
                      _destinationLocationId = _defaultLocation(
                        warehouses,
                        value,
                      )?.id;
                      _markDirty();
                    }),
                    onLocationChanged: (value) => setState(() {
                      _destinationLocationId = value;
                      _markDirty();
                    }),
                  ),
                ),
              ],
            ),
            if (movementError != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      movementError,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Puedes mover entre ubicaciones de la misma bodega o entre bodegas.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _endpointColumn(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String warehouseLabel,
    required String locationLabel,
    required String? warehouseId,
    required String? locationId,
    required List<WarehouseDto> warehouses,
    required ValueChanged<String?> onWarehouseChanged,
    required ValueChanged<String?> onLocationChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        _warehouseField(
          warehouses,
          label: warehouseLabel,
          value: warehouseId,
          onChanged: onWarehouseChanged,
        ),
        const SizedBox(height: 12),
        _locationField(
          warehouses,
          warehouseId: warehouseId,
          value: locationId,
          label: locationLabel,
          onChanged: onLocationChanged,
        ),
      ],
    );
  }

  Widget _adjustmentCard(BuildContext context, List<WarehouseDto> warehouses) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aplicar en', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _warehouseField(
              warehouses,
              label: 'Bodega',
              value: _destinationWarehouseId,
              onChanged: (value) => setState(() {
                _destinationWarehouseId = value;
                _destinationLocationId = _defaultLocation(
                  warehouses,
                  value,
                )?.id;
                _markDirty();
              }),
            ),
            const SizedBox(height: 12),
            _locationField(
              warehouses,
              warehouseId: _destinationWarehouseId,
              value: _destinationLocationId,
              label: 'Ubicación',
              onChanged: (value) => setState(() {
                _destinationLocationId = value;
                _markDirty();
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'La ubicación predeterminada se propone automáticamente y puedes cambiarla.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Error del movimiento o null si origen y destino son válidos.
  String? _movementError() {
    if (_originWarehouseId == null ||
        _originLocationId == null ||
        _destinationWarehouseId == null ||
        _destinationLocationId == null) {
      return 'Selecciona bodega y ubicación de origen y destino.';
    }
    if (_originLocationId == _destinationLocationId) {
      return 'El origen y el destino no pueden ser la misma ubicación. '
          'Elige otra ubicación o intercambia el sentido.';
    }
    return null;
  }

  /// Error de una línea o null si está lista para guardar.
  String? _lineError(
    _DocumentLineDraft line, {
    required bool isTransfer,
    required Map<String, int> availability,
  }) {
    final quantity = int.tryParse(line.quantity.text.trim());
    if (line.productId == null || quantity == null || quantity == 0) {
      return null;
    }
    if (!isTransfer) return null;
    final available = availability[line.productId] ?? 0;
    if (quantity.abs() > available) {
      return available == 0
          ? 'Sin existencias en la ubicación de origen.'
          : 'Solo hay $available disponible(s) en el origen.';
    }
    return null;
  }

  Widget _lineCard(
    BuildContext context,
    List<ProductSummaryDto> products,
    int index, {
    required String? lineError,
    required int? available,
    required bool isTransfer,
  }) {
    final line = _lines[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _productField(products, line)),
                const SizedBox(width: 12),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.tab &&
                          index == _lines.length - 1 &&
                          line.productId != null &&
                          int.tryParse(line.quantity.text) != null) {
                        _addLine();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      focusNode: line.quantityFocus,
                      controller: line.quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Cantidad',
                        helperText: _type == InventoryDocumentType.adjustment
                            ? '+ suma / − resta'
                            : 'Cantidad a trasladar',
                        errorText: lineError,
                      ),
                      onChanged: (_) => setState(_markDirty),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Agregar línea después',
                  onPressed: () => _addLine(afterIndex: index),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                IconButton(
                  tooltip: 'Quitar línea',
                  onPressed: _lines.length == 1
                      ? null
                      : () => setState(() {
                          _lines.removeAt(index).dispose();
                          _markDirty();
                        }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (isTransfer && line.productId != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    available == null || available == 0
                        ? 'Disponible en origen: 0'
                        : 'Disponible en origen: $available',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: available == null || available == 0
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _warehouseField(
    List<WarehouseDto> warehouses, {
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
    List<WarehouseDto> warehouses, {
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
    List<ProductSummaryDto> products,
    _DocumentLineDraft line,
  ) => RawAutocomplete<ProductSummaryDto>(
    textEditingController: line.productSearch,
    focusNode: line.productFocus,
    displayStringForOption: (product) => '${product.sku} · ${product.name}',
    optionsBuilder: (value) {
      final query = value.text.trim().toLowerCase();
      if (query.isEmpty) return const Iterable<ProductSummaryDto>.empty();
      return products.where(
        (product) =>
            product.sku.toLowerCase().contains(query) ||
            product.name.toLowerCase().contains(query) ||
            product.description.toLowerCase().contains(query),
      );
    },
    onSelected: (product) {
      setState(() {
        line.productId = product.id;
        _markDirty();
      });
      line.quantityFocus.requestFocus();
    },
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (_) => setState(() {
            line.productId = null;
            _markDirty();
          }),
          onSubmitted: (_) => onSubmitted(),
          decoration: const InputDecoration(
            labelText: 'Producto',
            hintText: 'Código, nombre o descripción',
            prefixIcon: Icon(Icons.search),
          ),
        ),
    optionsViewBuilder: (context, onSelected, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 320),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final product = options.elementAt(index);
              return ListTile(
                title: Text('${product.sku} · ${product.name}'),
                subtitle: Text(
                  product.description.isEmpty
                      ? 'Sin descripción'
                      : product.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text('Stock ${product.currentStock}'),
                onTap: () => onSelected(product),
              );
            },
          ),
        ),
      ),
    ),
  );

  void _addLine({int? afterIndex}) {
    final line = _DocumentLineDraft();
    setState(() {
      if (afterIndex == null) {
        _lines.add(line);
      } else {
        _lines.insert(afterIndex + 1, line);
      }
      _markDirty();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) line.productFocus.requestFocus();
    });
  }

  WarehouseDto? _defaultWarehouse(List<WarehouseDto> warehouses) {
    if (warehouses.isEmpty) return null;
    return warehouses.firstWhere(
      (warehouse) => warehouse.isDefault,
      orElse: () => warehouses.first,
    );
  }

  InventoryLocationDto? _defaultLocation(
    List<WarehouseDto> warehouses,
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

  Future<void> _save(BuildContext context, {bool draft = false}) async {
    if (_destinationWarehouseId == null || _destinationLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la bodega y ubicación de destino.'),
        ),
      );
      return;
    }
    if (_type == InventoryDocumentType.transfer) {
      final movementError = _movementError();
      if (movementError != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(movementError)));
        return;
      }
      if (_originWarehouseId == null || _originLocationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona la bodega y ubicación de origen.'),
          ),
        );
        return;
      }
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
              originLocationId: _type == InventoryDocumentType.transfer
                  ? _originLocationId
                  : null,
              destinationWarehouseId: _destinationWarehouseId,
              destinationLocationId: _destinationLocationId,
              externalReference: _reference.text.trim(),
              notes: _notes.text.trim(),
              draft: _type == InventoryDocumentType.transfer ? draft : false,
            ),
          );
      ref.read(inventoryDataRevisionProvider.notifier).notifyChanged();
      ref.read(productDataRevisionProvider.notifier).notifyChanged();
      if (context.mounted) {
        _markClean();
        context.go('/inventory/documents/${document.id}');
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible guardar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DocumentLineDraft {
  String? productId;
  final productSearch = TextEditingController();
  final quantity = TextEditingController();
  final productFocus = FocusNode();
  final quantityFocus = FocusNode();

  void dispose() {
    productSearch.dispose();
    productFocus.dispose();
    quantity.dispose();
    quantityFocus.dispose();
  }
}
