import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/identity/identity_context_provider.dart';
import '../../../../core/utilities/phone_number.dart';
import '../../../../shared/navigation/unsaved_changes_guard.dart';
import '../../api/sales_api.dart';
import '../../../../shared/utilities/search_query.dart';
import '../../../../shared/widgets/document_list_controls.dart';
import '../../../../shared/widgets/list_kpi_strip.dart';

class AgentPage extends ConsumerStatefulWidget {
  const AgentPage({super.key});

  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends ConsumerState<AgentPage> {
  final _search = TextEditingController();
  String _status = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            : Builder(
                builder: (context) {
                  final query = effectiveSearchQuery(_search.text)
                      .toLowerCase();
                  final filtered = items.where((agent) {
                    if (_status == 'ACTIVE' && !agent.isActive) return false;
                    if (_status == 'INACTIVE' && agent.isActive) return false;
                    return query.isEmpty ||
                        [
                          agent.name,
                          agent.phone,
                        ].join(' ').toLowerCase().contains(query);
                  }).toList();
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                    itemCount: filtered.isEmpty ? 2 : filtered.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: DocumentListControls(
                            searchController: _search,
                            searchLabel: 'Buscar agentes',
                            searchHint: 'Nombre o teléfono',
                            onSearchChanged: (_) => setState(() {}),
                            statusValue: _status,
                            statusOptions: const [
                              (value: 'ACTIVE', label: 'Activos'),
                              (value: 'INACTIVE', label: 'Inactivos'),
                              (value: 'ALL', label: 'Todos'),
                            ],
                            onStatusChanged: (value) =>
                                setState(() => _status = value),
                            kpis: [
                              ListKpi(
                                label: 'Total',
                                value: items.length,
                                icon: Icons.badge_outlined,
                              ),
                              ListKpi(
                                label: 'Activos',
                                value: items.where((a) => a.isActive).length,
                                icon: Icons.person_outline,
                              ),
                              ListKpi(
                                label: 'Inactivos',
                                value: items.where((a) => !a.isActive).length,
                                icon: Icons.person_off_outlined,
                              ),
                            ],
                            resultCount: filtered.length,
                            totalCount: items.length,
                            onClear: () => setState(() {
                              _search.clear();
                              _status = 'ALL';
                            }),
                          ),
                        );
                      }
                      if (filtered.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No hay agentes para esos criterios.'),
                          ),
                        );
                      }
                      final agent = filtered[index - 1];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(agent.name),
                        subtitle: Text(
                          displayPhone(agent.phone).isEmpty
                              ? 'Sin teléfono'
                              : displayPhone(agent.phone),
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
                                onPressed: () =>
                                    _deactivate(context, ref, agent),
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
    final phone = splitPhoneNumber(existing?.phone);
    final phoneCountryCode = TextEditingController(text: phone.countryCode);
    final phoneLocal = TextEditingController(text: phone.localNumber);
    String? nameError;
    String? phoneError;
    var dirty = false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void markDirty() {
            if (dirty) return;
            setDialogState(() => dirty = true);
          }

          Future<void> cancel() async {
            final navigator = Navigator.of(context);
            final discard = await UnsavedChangesGuard.instance.confirmDiscard(
              context,
              hasUnsavedChanges: dirty,
            );
            if (discard && context.mounted) navigator.pop(false);
          }

          void submit() {
            if (name.text.trim().isEmpty) {
              setDialogState(() {
                nameError = 'Escriba el nombre del agente.';
              });
              return;
            }
            if (phoneLocal.text.trim().isNotEmpty &&
                !isValidLocalPhone(phoneLocal.text)) {
              setDialogState(() {
                phoneError = 'Ingrese al menos 8 dígitos.';
              });
              return;
            }
            Navigator.pop(context, true);
          }

          return PopScope(
            canPop: !dirty,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await cancel();
            },
            child: AlertDialog(
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
                      markDirty();
                      if (nameError != null) {
                        setDialogState(() => nameError = null);
                      }
                    },
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: phoneCountryCode,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'País',
                            hintText: '+506',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => markDirty(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: phoneLocal,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'WhatsApp',
                            hintText: '24357658',
                            errorText: phoneError,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            markDirty();
                            if (phoneError != null) {
                              setDialogState(() => phoneError = null);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: cancel, child: const Text('Cancelar')),
                FilledButton(onPressed: submit, child: const Text('Guardar')),
              ],
            ),
          );
        },
      ),
    );
    if (accepted == true) {
      final api = ref.read(salesApiProvider);
      final identity = ref.read(identityContextProvider);
      final formattedPhone =
          nullableFormattedPhone(
            countryCode: phoneCountryCode.text,
            localNumber: phoneLocal.text,
          ) ??
          '';
      if (existing == null) {
        await api.createAgent(
          CreateSalesAgentCommand(
            commandId: const Uuid().v4(),
            name: name.text,
            phone: formattedPhone,
            identity: identity,
          ),
        );
      } else {
        await api.updateAgent(
          UpdateSalesAgentCommand(
            id: existing.id,
            name: name.text,
            phone: formattedPhone,
            expectedVersion: existing.version,
            identity: identity,
          ),
        );
      }
      ref.invalidate(salesAgentsProvider);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      phoneCountryCode.dispose();
      phoneLocal.dispose();
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
