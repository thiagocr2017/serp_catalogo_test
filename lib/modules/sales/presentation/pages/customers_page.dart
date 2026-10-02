import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/customer_api.dart';
import '../../../../shared/widgets/status_chip.dart';

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null, const []),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo cliente'),
      ),
      body: customersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(child: Text('No hay clientes registrados.'));
          }
          final giras = {
            for (final customer in customers)
              if (customer.gira?.trim().isNotEmpty == true)
                customer.gira!.trim(),
          }.toList()..sort();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              final place = [
                if (customer.gira?.trim().isNotEmpty == true)
                  'Gira ${customer.gira!.trim()}',
                if (customer.province?.trim().isNotEmpty == true)
                  customer.province!.trim(),
              ].join(' · ');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(customer.name),
                  subtitle: Text(
                    [
                      if (place.isNotEmpty) place,
                      customer.phone ?? customer.email ?? '',
                    ].where((part) => part.isNotEmpty).join('\n'),
                  ),
                  isThreeLine: place.isNotEmpty,
                  trailing: StatusChip(
                    label: customer.isActive ? 'Activo' : 'Inactivo',
                    tone: customer.isActive
                        ? StatusTone.success
                        : StatusTone.danger,
                  ),
                  onTap: () => _edit(context, ref, customer, giras),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Customer? existing,
    List<String> existingGiras,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: _CustomerDialog(
            existing: existing,
            existingGiras: existingGiras,
          ),
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ref.invalidate(customersProvider);
    }
  }
}

class _ContactDraft {
  _ContactDraft({this.id, String? name, String? phone, String? role})
    : name = TextEditingController(text: name ?? ''),
      phone = TextEditingController(text: phone ?? ''),
      role = TextEditingController(text: role ?? '');

  final String? id;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController role;

  void dispose() {
    name.dispose();
    phone.dispose();
    role.dispose();
  }
}

class _CustomerDialog extends ConsumerStatefulWidget {
  const _CustomerDialog({this.existing, this.existingGiras = const []});

  final Customer? existing;
  final List<String> existingGiras;

  @override
  ConsumerState<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends ConsumerState<_CustomerDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _taxId;
  late final TextEditingController _creditLimit;
  late final TextEditingController _province;
  late final TextEditingController _gira;
  final _contacts = <_ContactDraft>[];
  final _removedContactIds = <String>[];
  bool _loadingContacts = false;
  bool _saving = false;
  String? _nameError;
  String? _creditLimitError;
  String? _contactsError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _phone = TextEditingController(text: existing?.phone ?? '');
    _email = TextEditingController(text: existing?.email ?? '');
    _address = TextEditingController(text: existing?.address ?? '');
    _taxId = TextEditingController(text: existing?.taxId ?? '');
    _creditLimit = TextEditingController(
      text: existing == null || existing.creditLimit == 0
          ? ''
          : existing.creditLimit.toString(),
    );
    _province = TextEditingController(text: existing?.province ?? '');
    _gira = TextEditingController(text: existing?.gira ?? '');
    if (existing != null) _loadContacts(existing.id);
  }

  Future<void> _loadContacts(String customerId) async {
    setState(() => _loadingContacts = true);
    try {
      final contacts = await ref
          .read(customerApiProvider)
          .getCustomerContacts(customerId);
      if (mounted) {
        setState(() {
          _contacts.addAll(
            contacts.map(
              (contact) => _ContactDraft(
                id: contact.id,
                name: contact.name,
                phone: contact.phone,
                role: contact.role,
              ),
            ),
          );
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible cargar contactos: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _taxId.dispose();
    _creditLimit.dispose();
    _province.dispose();
    _gira.dispose();
    for (final contact in _contacts) {
      contact.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return AlertDialog(
      title: Text(existing == null ? 'Nuevo cliente' : 'Editar cliente'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nombre del negocio',
                  errorText: _nameError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _taxId,
                decoration: const InputDecoration(
                  labelText: 'Cédula jurídica / Tax ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _creditLimit,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Límite de crédito',
                  errorText: _creditLimitError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_creditLimitError != null) {
                    setState(() => _creditLimitError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _province,
                decoration: const InputDecoration(
                  labelText: 'Provincia',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _gira.text),
                optionsBuilder: (value) {
                  final query = value.text.trim().toLowerCase();
                  final options = widget.existingGiras.where(
                    (gira) =>
                        gira.toLowerCase() != _gira.text.trim().toLowerCase(),
                  );
                  if (query.isEmpty) return options;
                  return options.where(
                    (gira) => gira.toLowerCase().contains(query),
                  );
                },
                onSelected: (value) => _gira.text = value,
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Gira (agrupación comercial)',
                          hintText: 'P. ej. Gira Sur',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => _gira.text = value,
                      );
                    },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Contactos de la empresa',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _contacts.add(_ContactDraft())),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              if (_loadingContacts)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              if (_contactsError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    _contactsError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              for (var index = 0; index < _contacts.length; index++)
                _contactRow(index),
              if (_contacts.isEmpty && !_loadingContacts)
                const Text('Sin contactos registrados.'),
            ],
          ),
        ),
      ),
      actions: [
        if (existing != null && existing.isActive)
          TextButton(
            onPressed: _saving ? null : () => _deactivate(existing),
            child: const Text('Desactivar'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _contactRow(int index) {
    final draft = _contacts[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.name,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del contacto',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_contactsError != null) {
                        setState(() => _contactsError = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Quitar contacto',
                  onPressed: () => setState(() {
                    if (draft.id != null) {
                      _removedContactIds.add(draft.id!);
                    }
                    _contacts.removeAt(index).dispose();
                  }),
                  icon: const Icon(Icons.delete_outline),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  flex: 1,
                  child: TextField(
                    controller: draft.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 1,
                  child: TextField(
                    controller: draft.role,
                    decoration: const InputDecoration(
                      labelText: 'Rol (Compras, Gerencia…)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Escriba el nombre del negocio.');
      return;
    }
    if (_contacts.any((draft) => draft.name.text.trim().isEmpty)) {
      setState(() => _contactsError = 'Cada contacto necesita un nombre.');
      return;
    }
    final creditLimitText = _creditLimit.text.trim();
    final creditLimit = creditLimitText.isEmpty
        ? null
        : double.tryParse(creditLimitText.replaceAll(',', '.'));
    if (creditLimitText.isNotEmpty && creditLimit == null) {
      setState(() => _creditLimitError = 'Ingrese un número válido.');
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(customerApiProvider);
      final existing = widget.existing;
      final province = _province.text.trim().isEmpty
          ? null
          : _province.text.trim();
      final gira = _gira.text.trim().isEmpty ? null : _gira.text.trim();
      final String customerId;
      if (existing == null) {
        final created = await api.createCustomer(
          name: _name.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          taxId: _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),
          creditLimit: creditLimit,
          province: province,
          gira: gira,
        );
        customerId = created.id;
      } else {
        await api.updateCustomer(
          id: existing.id,
          name: _name.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          taxId: _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),
          creditLimit: creditLimit,
          province: province,
          gira: gira,
        );
        customerId = existing.id;
      }
      for (final removedId in _removedContactIds) {
        await api.deleteCustomerContact(removedId);
      }
      for (final draft in _contacts) {
        await api.saveCustomerContact(
          id: draft.id,
          customerId: customerId,
          name: draft.name.text.trim(),
          phone: draft.phone.text.trim().isEmpty
              ? null
              : draft.phone.text.trim(),
          role: draft.role.text.trim().isEmpty ? null : draft.role.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible guardar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deactivate(Customer customer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar cliente'),
        content: Text(
          '¿Desactivar a ${customer.name}? Dejará de aparecer entre los activos.',
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
    if (confirm != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(customerApiProvider).deactivateCustomer(customer.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible desactivar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
