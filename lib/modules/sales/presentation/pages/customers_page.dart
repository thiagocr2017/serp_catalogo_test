import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utilities/phone_number.dart';
import '../../../../shared/navigation/unsaved_changes_guard.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../configuration/configuration_module.dart';
import '../../api/customer_api.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _search = TextEditingController();
  String _statusFilter = 'ALL';
  String _typeFilter = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/sales/customers/new'),
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
          final query = _search.text.trim().toLowerCase();
          final filtered = customers.where((customer) {
            final matchesStatus =
                _statusFilter == 'ALL' ||
                (_statusFilter == 'ACTIVE' && customer.isActive) ||
                (_statusFilter == 'INACTIVE' && !customer.isActive);
            final matchesType =
                _typeFilter == 'ALL' || customer.customerType == _typeFilter;
            final haystack = [
              customer.name,
              customer.displayName,
              customer.phone,
              customer.email,
              customer.taxId,
              customer.province,
              customer.gira,
            ].whereType<String>().join(' ').toLowerCase();
            final matchesQuery =
                query.isEmpty ||
                query
                    .split(RegExp(r'\s+'))
                    .where((term) => term.isNotEmpty)
                    .every(haystack.contains);
            return matchesStatus && matchesType && matchesQuery;
          }).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Buscar cliente',
                        hintText: 'Nombre, fantasía, teléfono, correo, gira...',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _statusFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'ACTIVE',
                          child: Text('Activos'),
                        ),
                        DropdownMenuItem(
                          value: 'INACTIVE',
                          child: Text('Inactivos'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _statusFilter = value ?? 'ALL'),
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      initialValue: _typeFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                        DropdownMenuItem(value: 'CASH', child: Text('Contado')),
                        DropdownMenuItem(
                          value: 'CREDIT',
                          child: Text('Crédito'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _typeFilter = value ?? 'ALL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No hay clientes para ese filtro.'),
                  ),
                ),
              for (final customer in filtered) ...[
                Builder(
                  builder: (context) {
                    final place = [
                      if (customer.gira?.trim().isNotEmpty == true)
                        'Gira ${customer.gira!.trim()}',
                      if (customer.province?.trim().isNotEmpty == true)
                        customer.province!.trim(),
                    ].join(' · ');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            customer.name.characters.first.toUpperCase(),
                          ),
                        ),
                        title: Text(
                          customer.displayName?.trim().isNotEmpty == true
                              ? '${customer.displayName} · ${customer.name}'
                              : customer.name,
                        ),
                        subtitle: Text(
                          [
                            customer.customerType == 'CREDIT'
                                ? 'Crédito${customer.creditDays == null ? '' : ' · ${customer.creditDays} días'}'
                                : 'Contado',
                            if (place.isNotEmpty) place,
                            displayPhone(customer.phone).isNotEmpty
                                ? displayPhone(customer.phone)
                                : customer.email ?? '',
                          ].where((part) => part.isNotEmpty).join('\n'),
                        ),
                        isThreeLine: place.isNotEmpty,
                        trailing: StatusChip(
                          label: customer.isActive ? 'Activo' : 'Inactivo',
                          tone: customer.isActive
                              ? StatusTone.success
                              : StatusTone.danger,
                        ),
                        onTap: () =>
                            context.go('/sales/customers/${customer.id}/edit'),
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ContactDraft {
  _ContactDraft({
    this.id,
    String? name,
    String? phone,
    String? role,
    DateTime? birthday,
  }) : name = TextEditingController(text: name ?? ''),
       countryCode = TextEditingController(
         text: splitPhoneNumber(phone).countryCode,
       ),
       phone = TextEditingController(text: splitPhoneNumber(phone).localNumber),
       role = TextEditingController(text: role ?? ''),
       birthday = TextEditingController(
         text: birthday == null ? '' : _dateText(birthday),
       );

  final String? id;
  final TextEditingController name;
  final TextEditingController countryCode;
  final TextEditingController phone;
  final TextEditingController role;
  final TextEditingController birthday;

  void dispose() {
    name.dispose();
    countryCode.dispose();
    phone.dispose();
    role.dispose();
    birthday.dispose();
  }
}

String _dateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({this.customerId, super.key});

  final String? customerId;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  late final TextEditingController _name;
  late final TextEditingController _displayName;
  late final TextEditingController _phoneCountryCode;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _taxId;
  late final TextEditingController _creditLimit;
  late final TextEditingController _creditDays;
  late final TextEditingController _province;
  late final TextEditingController _gira;
  late String? _preferredCarrierId;
  late String _customerType;
  late String _documentPreference;
  final _contacts = <_ContactDraft>[];
  final _removedContactIds = <String>[];
  Customer? _existing;
  bool _loadingCustomer = false;
  bool _loadingContacts = false;
  bool _saving = false;
  bool _dirty = false;
  bool _hydrating = false;
  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _creditLimitError;
  String? _creditDaysError;
  String? _contactsError;

  @override
  void initState() {
    super.initState();
    final existing = _existing;
    final phone = splitPhoneNumber(existing?.phone);
    _name = TextEditingController(text: existing?.name ?? '');
    _displayName = TextEditingController(text: existing?.displayName ?? '');
    _phoneCountryCode = TextEditingController(text: phone.countryCode);
    _phone = TextEditingController(text: phone.localNumber);
    _email = TextEditingController(text: existing?.email ?? '');
    _address = TextEditingController(text: existing?.address ?? '');
    _taxId = TextEditingController(text: existing?.taxId ?? '');
    _creditLimit = TextEditingController(
      text: existing == null || existing.creditLimit == 0
          ? ''
          : existing.creditLimit.toString(),
    );
    _creditDays = TextEditingController(
      text: existing?.creditDays == null ? '' : existing!.creditDays.toString(),
    );
    _province = TextEditingController(text: existing?.province ?? '');
    _gira = TextEditingController(text: existing?.gira ?? '');
    _preferredCarrierId = existing?.preferredCarrierId;
    _customerType = existing?.customerType ?? 'CASH';
    _documentPreference = existing?.documentPreference ?? 'E_INVOICE';
    for (final controller in [
      _name,
      _displayName,
      _phoneCountryCode,
      _phone,
      _email,
      _address,
      _taxId,
      _creditLimit,
      _creditDays,
      _province,
      _gira,
    ]) {
      controller.addListener(_markDirty);
    }
    if (widget.customerId != null) _loadCustomer(widget.customerId!);
  }

  Future<void> _loadCustomer(String customerId) async {
    setState(() => _loadingCustomer = true);
    try {
      final customer = await ref
          .read(customerApiProvider)
          .getCustomerById(customerId);
      if (!mounted) return;
      if (customer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró el cliente.')),
        );
        _returnToCustomers();
        return;
      }
      final phone = splitPhoneNumber(customer.phone);
      _hydrating = true;
      setState(() {
        _existing = customer;
        _name.text = customer.name;
        _displayName.text = customer.displayName ?? '';
        _phoneCountryCode.text = phone.countryCode;
        _phone.text = phone.localNumber;
        _email.text = customer.email ?? '';
        _address.text = customer.address ?? '';
        _taxId.text = customer.taxId ?? '';
        _creditLimit.text = customer.creditLimit == 0
            ? ''
            : customer.creditLimit.toString();
        _creditDays.text = customer.creditDays?.toString() ?? '';
        _province.text = customer.province ?? '';
        _gira.text = customer.gira ?? '';
        _preferredCarrierId = customer.preferredCarrierId;
        _customerType = customer.customerType;
        _documentPreference = customer.documentPreference;
      });
      _hydrating = false;
      await _loadContacts(customer.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible cargar cliente: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCustomer = false);
    }
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
                birthday: contact.birthday,
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

  void _returnToCustomers() {
    _markClean();
    ref.invalidate(customersProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/sales/customers');
    });
  }

  void _markDirty() {
    if (_hydrating || _saving) return;
    _dirty = true;
    UnsavedChangesGuard.instance.markDirty();
  }

  void _markClean() {
    _dirty = false;
    UnsavedChangesGuard.instance.markClean();
  }

  Future<void> _cancel() async {
    if (_saving) return;
    if (_dirty &&
        !await UnsavedChangesGuard.instance.confirmNavigation(context)) {
      return;
    }
    _markClean();
    if (mounted) context.go('/sales/customers');
  }

  @override
  void dispose() {
    _name.dispose();
    _displayName.dispose();
    _phoneCountryCode.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _taxId.dispose();
    _creditLimit.dispose();
    _creditDays.dispose();
    _province.dispose();
    _gira.dispose();
    for (final contact in _contacts) {
      contact.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    final existingGiras = {
      for (final customer in ref.watch(customersProvider).value ?? <Customer>[])
        if (customer.gira?.trim().isNotEmpty == true) customer.gira!.trim(),
    }.toList()..sort();
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
        appBar: AppBar(
          title: Text(existing == null ? 'Nuevo cliente' : 'Editar cliente'),
        ),
        body: _loadingCustomer
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _section(
                          title: 'Datos del cliente',
                          icon: Icons.storefront_outlined,
                          children: [
                            TextField(
                              controller: _name,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: 'Nombre fiscal / negocio',
                                errorText: _nameError,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                if (_nameError != null) {
                                  setState(() => _nameError = null);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _displayName,
                              decoration: const InputDecoration(
                                labelText: 'Nombre fantasía',
                                hintText:
                                    'Nombre interno para buscar y recordar',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                SizedBox(
                                  width: 96,
                                  child: TextField(
                                    controller: _phoneCountryCode,
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
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _phone,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Teléfono',
                                      hintText: '24357658',
                                      errorText: _phoneError,
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (_) {
                                      if (_phoneError != null) {
                                        setState(() => _phoneError = null);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Correo principal',
                                errorText: _emailError,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                if (_emailError != null) {
                                  setState(() => _emailError = null);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _taxId,
                              decoration: const InputDecoration(
                                labelText: 'Cédula jurídica / Tax ID',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _section(
                          title: 'Crédito y documentos',
                          icon: Icons.receipt_long_outlined,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _customerType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de cliente',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'CASH',
                                  child: Text('Contado'),
                                ),
                                DropdownMenuItem(
                                  value: 'CREDIT',
                                  child: Text('Crédito'),
                                ),
                              ],
                              onChanged: (value) => setState(() {
                                _customerType = value ?? 'CASH';
                                _markDirty();
                              }),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _creditDays,
                                    enabled: _customerType == 'CREDIT',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Días de crédito',
                                      errorText: _creditDaysError,
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (_) {
                                      if (_creditDaysError != null) {
                                        setState(() => _creditDaysError = null);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _creditLimit,
                                    enabled: _customerType == 'CREDIT',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: 'Límite de crédito',
                                      hintText: '0 = sin límite',
                                      errorText: _creditLimitError,
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (_) {
                                      if (_creditLimitError != null) {
                                        setState(
                                          () => _creditLimitError = null,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _documentPreference,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Documento habitual',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'E_INVOICE',
                                  child: Text('Factura electrónica'),
                                ),
                                DropdownMenuItem(
                                  value: 'TICKET',
                                  child: Text('Tiquete'),
                                ),
                                DropdownMenuItem(
                                  value: 'ASK_EACH_TIME',
                                  child: Text('Preguntar al facturar'),
                                ),
                              ],
                              onChanged: (value) => setState(() {
                                _documentPreference = value ?? 'E_INVOICE';
                                _markDirty();
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _section(
                          title: 'Ubicación y envío',
                          icon: Icons.local_shipping_outlined,
                          children: [
                            TextField(
                              controller: _address,
                              decoration: const InputDecoration(
                                labelText: 'Dirección',
                                border: OutlineInputBorder(),
                              ),
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
                                final options = existingGiras.where(
                                  (gira) =>
                                      gira.toLowerCase() !=
                                      _gira.text.trim().toLowerCase(),
                                );
                                if (query.isEmpty) return options;
                                return options.where(
                                  (gira) => gira.toLowerCase().contains(query),
                                );
                              },
                              onSelected: (value) {
                                _gira.text = value;
                                _markDirty();
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    controller,
                                    focusNode,
                                    onSubmitted,
                                  ) {
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'Gira (agrupación comercial)',
                                        hintText: 'P. ej. Gira Sur',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        _gira.text = value;
                                        _markDirty();
                                      },
                                    );
                                  },
                            ),
                            const SizedBox(height: 12),
                            ref
                                .watch(carrierDtosProvider)
                                .when(
                                  loading: () =>
                                      const LinearProgressIndicator(),
                                  error: (error, _) => Text(
                                    'No fue posible cargar transportes: $error',
                                  ),
                                  data: (carriers) =>
                                      DropdownButtonFormField<String?>(
                                        initialValue: _preferredCarrierId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Transporte preferido',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: [
                                          const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text(
                                              'Sin transporte preferido',
                                            ),
                                          ),
                                          for (final carrier in carriers)
                                            DropdownMenuItem<String?>(
                                              value: carrier.id,
                                              child: Text(carrier.name),
                                            ),
                                        ],
                                        onChanged: (value) => setState(() {
                                          _preferredCarrierId = value;
                                          _markDirty();
                                        }),
                                      ),
                                ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _section(
                          title: 'Contactos de la empresa',
                          icon: Icons.contacts_outlined,
                          trailing: TextButton.icon(
                            onPressed: () => setState(() {
                              _contacts.add(_ContactDraft());
                              _markDirty();
                            }),
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar'),
                          ),
                          children: [
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
                            for (
                              var index = 0;
                              index < _contacts.length;
                              index++
                            )
                              _contactRow(index),
                            if (_contacts.isEmpty && !_loadingContacts)
                              const Text('Sin contactos registrados.'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Row(
              children: [
                if (existing != null && existing.isActive)
                  TextButton.icon(
                    onPressed: _saving ? null : () => _deactivate(existing),
                    icon: const Icon(Icons.block),
                    label: const Text('Desactivar'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : _cancel,
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
      const SizedBox(height: 12),
      ...children,
    ],
  );

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
                      _markDirty();
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
                    _markDirty();
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
                SizedBox(
                  width: 88,
                  child: TextField(
                    controller: draft.countryCode,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'País',
                      hintText: '+506',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_contactsError != null) {
                        setState(() => _contactsError = null);
                      }
                      _markDirty();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 1,
                  child: TextField(
                    controller: draft.phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      hintText: '24357658',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_contactsError != null) {
                        setState(() => _contactsError = null);
                      }
                      _markDirty();
                    },
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
                    onChanged: (_) {
                      if (_contactsError != null) {
                        setState(() => _contactsError = null);
                      }
                      _markDirty();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.birthday,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                labelText: 'Cumpleaños',
                hintText: 'AAAA-MM-DD',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _markDirty(),
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
    if (_phone.text.trim().isNotEmpty && !isValidLocalPhone(_phone.text)) {
      setState(() => _phoneError = 'Ingrese al menos 8 dígitos.');
      return;
    }
    final email = _email.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      setState(() => _emailError = 'Ingrese un correo válido.');
      return;
    }
    if (_contacts.any(
      (draft) =>
          draft.name.text.trim().isEmpty ||
          draft.phone.text.trim().isEmpty ||
          draft.role.text.trim().isEmpty ||
          !isValidLocalPhone(draft.phone.text),
    )) {
      setState(
        () => _contactsError = 'Cada contacto necesita nombre, teléfono de al menos 8 dígitos y cargo.',
      );
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
    final creditDaysText = _creditDays.text.trim();
    final creditDays = creditDaysText.isEmpty
        ? null
        : int.tryParse(creditDaysText);
    if (_customerType == 'CREDIT' && (creditDays == null || creditDays <= 0)) {
      setState(() => _creditDaysError = 'Ingrese días de crédito.');
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(customerApiProvider);
      final existing = _existing;
      final province = _province.text.trim().isEmpty
          ? null
          : _province.text.trim();
      final gira = _gira.text.trim().isEmpty ? null : _gira.text.trim();
      final phone = nullableFormattedPhone(
        countryCode: _phoneCountryCode.text,
        localNumber: _phone.text,
      );
      final String customerId;
      if (existing == null) {
        final created = await api.createCustomer(
          name: _name.text.trim(),
          displayName: _displayName.text.trim().isEmpty
              ? null
              : _displayName.text.trim(),
          phone: phone,
          email: email.isEmpty ? null : email,
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          taxId: _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),
          creditLimit: creditLimit,
          province: province,
          gira: gira,
          preferredCarrierId: _preferredCarrierId,
          customerType: _customerType,
          creditDays: _customerType == 'CREDIT' ? creditDays : null,
          documentPreference: _documentPreference,
        );
        customerId = created.id;
      } else {
        await api.updateCustomer(
          id: existing.id,
          name: _name.text.trim(),
          displayName: _displayName.text.trim().isEmpty
              ? null
              : _displayName.text.trim(),
          phone: phone,
          email: email.isEmpty ? null : email,
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          taxId: _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),
          creditLimit: creditLimit,
          province: province,
          gira: gira,
          preferredCarrierId: _preferredCarrierId,
          customerType: _customerType,
          creditDays: _customerType == 'CREDIT' ? creditDays : null,
          documentPreference: _documentPreference,
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
          phone: nullableFormattedPhone(
            countryCode: draft.countryCode.text,
            localNumber: draft.phone.text,
          ),
          role: draft.role.text.trim().isEmpty ? null : draft.role.text.trim(),
          birthday: _parseDate(draft.birthday.text),
        );
      }
      if (mounted) _returnToCustomers();
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

  bool _isValidEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }

  Future<void> _deactivate(Customer customer) async {
    final reason = TextEditingController();
    String? reasonError;
    var dirty = false;
    final confirm = await showDialog<bool>(
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

          return PopScope(
            canPop: !dirty,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await cancel();
            },
            child: AlertDialog(
              title: const Text('Desactivar cliente'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '¿Desactivar a ${customer.name}? Dejará de aparecer entre los activos.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reason,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Motivo',
                      errorText: reasonError,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      markDirty();
                      if (reasonError != null) {
                        setDialogState(() => reasonError = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: cancel, child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () {
                    if (reason.text.trim().isEmpty) {
                      setDialogState(
                        () =>
                            reasonError = 'Escriba el motivo de desactivación.',
                      );
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Desactivar'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (confirm != true || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(customerApiProvider)
          .deactivateCustomer(customer.id, reason: reason.text.trim());
      if (mounted) _returnToCustomers();
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
