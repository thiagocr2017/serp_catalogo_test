import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/identity/identity_context_provider.dart';
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
                        if (agent.isActive)
                          IconButton(
                            tooltip: 'Desactivar agente',
                            onPressed: () => _deactivate(context, ref, agent),
                            icon: const Icon(Icons.person_off_outlined),
                          )
                        else
                          IconButton(
                            tooltip: 'Activar agente',
                            onPressed: () => _activate(context, ref, agent),
                            icon: const Icon(Icons.person_add_alt_outlined),
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
    String? nameError;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submit() {
            if (name.text.trim().isEmpty) {
              setDialogState(() {
                nameError = 'Escriba el nombre del agente.';
              });
              return;
            }
            Navigator.pop(context, true);
          }

          return AlertDialog(
            title: Text(existing == null ? 'Nuevo agente' : 'Editar agente'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    errorText: nameError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (nameError != null) {
                      setDialogState(() => nameError = null);
                    }
                  },
                  onSubmitted: (_) => submit(),
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
              FilledButton(onPressed: submit, child: const Text('Guardar')),
            ],
          );
        },
      ),
    );
    if (accepted == true) {
      final api = ref.read(salesApiProvider);
      final identity = ref.read(identityContextProvider);
      if (existing == null) {
        await api.createAgent(
          CreateSalesAgentCommand(
            commandId: const Uuid().v4(),
            name: name.text,
            phone: phone.text,
            identity: identity,
          ),
        );
      } else {
        await api.updateAgent(
          UpdateSalesAgentCommand(
            id: existing.id,
            name: name.text,
            phone: phone.text,
            expectedVersion: existing.version,
            identity: identity,
          ),
        );
      }
      ref.invalidate(salesAgentsProvider);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      phone.dispose();
    });
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
      await ref
          .read(salesApiProvider)
          .deactivateAgent(
            DeactivateSalesAgentCommand(
              id: agent.id,
              expectedVersion: agent.version,
              identity: ref.read(identityContextProvider),
            ),
          );
      ref.invalidate(salesAgentsProvider);
    }
  }

  Future<void> _activate(
    BuildContext context,
    WidgetRef ref,
    SalesAgentDto agent,
  ) async {
    await ref
        .read(salesApiProvider)
        .activateAgent(
          ActivateSalesAgentCommand(
            id: agent.id,
            expectedVersion: agent.version,
            identity: ref.read(identityContextProvider),
          ),
        );
    ref.invalidate(salesAgentsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Agente activado.')));
    }
  }
}
