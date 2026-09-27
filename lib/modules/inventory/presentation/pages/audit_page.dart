import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/inventory_providers.dart';

class AuditPage extends ConsumerWidget {
  const AuditPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(auditEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Auditoría')),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No fue posible cargar: $e')),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (_, i) {
            final item = items[i];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                '${item.tableName}.${item.fieldName} · ${item.operation}',
              ),
              subtitle: Text(
                '${item.oldValue ?? '∅'} → ${item.newValue ?? '∅'}\n${item.actorName ?? 'Sistema'} · ${item.deviceName ?? 'Sin dispositivo'}',
              ),
              trailing: Text(item.createdAt.toLocal().toString()),
              isThreeLine: true,
            );
          },
        ),
      ),
    );
  }
}
