import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/sales_api.dart';

class AgentPage extends ConsumerWidget {
  const AgentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(salesAgentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Agentes de ventas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo agente'),
      ),
      body: agents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No fue posible cargar: $error')),
        data: (items) => items.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.badge_outlined, size: 56),
                    SizedBox(height: 12),
                    Text('No existen agentes de ventas.'),
                    SizedBox(height: 4),
                    Text('Crea un agente para asignarlo a los catálogos.'),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final agent = items[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(agent.name),
                    subtitle: Text(
                      agent.phone.isEmpty ? 'Sin teléfono' : agent.phone,
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Editar agente',
                          onPressed: () => _edit(context, ref, agent),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Desactivar agente',
                          onPressed: () => _deactivate(context, ref, agent),
                          icon: const Icon(Icons.person_off_outlined),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    SalesAgentDto? existing,
  ]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '+506');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nuevo agente' : 'Editar agente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, name.text.trim().isNotEmpty),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final api = ref.read(salesApiProvider);
      if (existing == null) {
        await api.createLegacyAgent(name: name.text, phone: phone.text);
      } else {
        await api.updateLegacyAgent(
          id: existing.id,
          name: name.text,
          phone: phone.text,
        );
      }
      ref.invalidate(salesAgentsProvider);
    }
    name.dispose();
    phone.dispose();
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    SalesAgentDto agent,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar agente'),
        content: Text(
          '¿Deseas desactivar a ${agent.name}? Dejará de aparecer en los catálogos nuevos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await ref.read(salesApiProvider).deactivateLegacyAgent(agent.id);
      ref.invalidate(salesAgentsProvider);
    }
  }
}
