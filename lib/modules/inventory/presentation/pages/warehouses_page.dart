import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/navigation/unsaved_changes_guard.dart';
import '../../api/inventory_api.dart';
import '../../di/inventory_providers.dart';

class WarehousesPage extends ConsumerWidget {
  const WarehousesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouses = ref.watch(warehousesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bodegas y ubicaciones'),
        actions: [
          FilledButton.icon(
            onPressed: () => _editWarehouse(context, ref),
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Nueva bodega'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: warehouses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No fue posible cargar las bodegas: $error')),
        data: (items) => items.isEmpty
            ? const Center(
                child: Text('No existen bodegas. Crea la primera para operar.'),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final warehouse = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      initiallyExpanded: warehouse.isDefault,
                      leading: const Icon(Icons.warehouse_outlined),
                      title: Text('${warehouse.code} · ${warehouse.name}'),
                      subtitle: Text(
                        warehouse.isDefault
                            ? 'Bodega predeterminada'
                            : '${warehouse.locations.length} ubicaciones',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Editar bodega',
                            onPressed: () =>
                                _editWarehouse(context, ref, warehouse),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Agregar ubicación',
                            onPressed: () =>
                                _editLocation(context, ref, warehouse),
                            icon: const Icon(Icons.add_location_alt_outlined),
                          ),
                        ],
                      ),
                      children: [
                        for (final location in warehouse.locations)
                          ListTile(
                            contentPadding: const EdgeInsets.only(
                              left: 72,
                              right: 24,
                            ),
                            leading: const Icon(Icons.location_on_outlined),
                            title: Text('${location.code} · ${location.name}'),
                            subtitle: location.isDefault
                                ? const Text('Ubicación predeterminada')
                                : null,
                            trailing: IconButton(
                              tooltip: 'Editar ubicación',
                              onPressed: () => _editLocation(
                                context,
                                ref,
                                warehouse,
                                location,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _editWarehouse(
    BuildContext context,
    WidgetRef ref, [
    WarehouseDto? warehouse,
  ]) async {
    final result = await showDialog<_WarehouseResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WarehouseDialog(
        title: warehouse == null ? 'Nueva bodega' : 'Editar bodega',
        initialCode: warehouse?.code ?? '',
        initialName: warehouse?.name ?? '',
      ),
    );
    if (result != null && context.mounted) {
      try {
        await ref
            .read(inventoryRepositoryProvider)
            .saveWarehouse(
              id: warehouse?.id,
              code: result.code,
              name: result.name,
            );
        ref.read(inventoryDataRevisionProvider.notifier).notifyChanged();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No fue posible guardar: $error')),
          );
        }
      }
    }
  }

  Future<void> _editLocation(
    BuildContext context,
    WidgetRef ref,
    WarehouseDto warehouse, [
    InventoryLocationDto? location,
  ]) async {
    final result = await showDialog<_WarehouseResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WarehouseDialog(
        title: location == null ? 'Nueva ubicación' : 'Editar ubicación',
        initialCode: location?.code ?? '',
        initialName: location?.name ?? '',
      ),
    );
    if (result != null && context.mounted) {
      try {
        await ref
            .read(inventoryRepositoryProvider)
            .saveLocation(
              id: location?.id,
              warehouseId: warehouse.id,
              code: result.code,
              name: result.name,
            );
        ref.read(inventoryDataRevisionProvider.notifier).notifyChanged();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No fue posible guardar: $error')),
          );
        }
      }
    }
  }
}

class _WarehouseResult {
  const _WarehouseResult({required this.code, required this.name});

  final String code;
  final String name;
}

class _WarehouseDialog extends StatefulWidget {
  const _WarehouseDialog({
    required this.title,
    required this.initialCode,
    required this.initialName,
  });

  final String title;
  final String initialCode;
  final String initialName;

  @override
  State<_WarehouseDialog> createState() => _WarehouseDialogState();
}

class _WarehouseDialogState extends State<_WarehouseDialog> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  String? _codeError;
  String? _nameError;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initialCode);
    _name = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _cancel();
      },
      child: AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _code,
                  decoration: InputDecoration(
                    labelText: 'Código',
                    errorText: _codeError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    _markDirty();
                    if (_codeError != null) setState(() => _codeError = null);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    errorText: _nameError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    _markDirty();
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _cancel, child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final code = _code.text.trim();
              final name = _name.text.trim();
              if (code.isEmpty || name.isEmpty) {
                setState(() {
                  _codeError = code.isEmpty ? 'Escriba el código.' : null;
                  _nameError = name.isEmpty ? 'Escriba el nombre.' : null;
                });
                return;
              }
              Navigator.pop(context, _WarehouseResult(code: code, name: name));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  Future<void> _cancel() async {
    final navigator = Navigator.of(context);
    final discard = await UnsavedChangesGuard.instance.confirmDiscard(
      context,
      hasUnsavedChanges: _dirty,
    );
    if (!discard || !mounted) return;
    navigator.pop();
  }
}
