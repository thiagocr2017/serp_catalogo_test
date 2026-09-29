import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    Warehouse? warehouse,
  ]) async {
    final code = TextEditingController(text: warehouse?.code);
    final name = TextEditingController(text: warehouse?.name);
    final accepted = await _formDialog(
      context,
      title: warehouse == null ? 'Nueva bodega' : 'Editar bodega',
      code: code,
      name: name,
    );
    if (accepted && context.mounted) {
      try {
        await ref
            .read(inventoryRepositoryProvider)
            .saveWarehouse(id: warehouse?.id, code: code.text, name: name.text);
        ref.read(inventoryDataRevisionProvider.notifier).notifyChanged();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No fue posible guardar: $error')),
          );
        }
      }
    }
    code.dispose();
    name.dispose();
  }

  Future<void> _editLocation(
    BuildContext context,
    WidgetRef ref,
    Warehouse warehouse, [
    InventoryLocation? location,
  ]) async {
    final code = TextEditingController(text: location?.code);
    final name = TextEditingController(text: location?.name);
    final accepted = await _formDialog(
      context,
      title: location == null ? 'Nueva ubicación' : 'Editar ubicación',
      code: code,
      name: name,
    );
    if (accepted && context.mounted) {
      try {
        await ref
            .read(inventoryRepositoryProvider)
            .saveLocation(
              id: location?.id,
              warehouseId: warehouse.id,
              code: code.text,
              name: name.text,
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
    code.dispose();
    name.dispose();
  }

  Future<bool> _formDialog(
    BuildContext context, {
    required String title,
    required TextEditingController code,
    required TextEditingController name,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (code.text.trim().isNotEmpty &&
                    name.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ) ??
      false;
}
