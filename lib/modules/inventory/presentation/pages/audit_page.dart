import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/inventory_providers.dart';

class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(auditEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Auditoría')),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No fue posible cargar: $e')),
        data: (items) {
          final query = _query.trim().toLowerCase();
          final filtered = query.isEmpty
              ? items
              : items.where((item) {
                  final searchable = [
                    item.tableName,
                    item.recordId,
                    item.operation,
                    item.fieldName,
                    item.oldValue,
                    item.newValue,
                    item.actorName,
                    item.deviceName,
                  ].whereType<String>().join(' ').toLowerCase();
                  return searchable.contains(query);
                }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    labelText: 'Buscar en auditoría',
                    hintText:
                        'Tabla, operación, campo, valor, usuario o equipo',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${filtered.length} registro(s)'),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No hay resultados para esta búsqueda.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          return ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(
                              '${item.tableName}.${item.fieldName} · ${item.operation}',
                            ),
                            subtitle: Text(
                              '${item.oldValue ?? '∅'} → ${item.newValue ?? '∅'}\n'
                              '${item.actorName ?? 'Sistema'} · '
                              '${item.deviceName ?? 'Sin dispositivo'}',
                            ),
                            trailing: Text(item.createdAt.toLocal().toString()),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
