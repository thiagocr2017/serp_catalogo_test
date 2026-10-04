import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utilities/phone_number.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../configuration/configuration_module.dart';
import '../../api/customer_api.dart';

class CustomerProfilePage extends ConsumerWidget {
  const CustomerProfilePage({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<Customer?>(
    future: ref.read(customerApiProvider).getCustomerById(customerId),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final customer = snapshot.data;
      if (customer == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Cliente')),
          body: const Center(child: Text('El cliente no existe.')),
        );
      }
      return _CustomerProfileView(customer: customer);
    },
  );
}

class _CustomerProfileView extends ConsumerWidget {
  const _CustomerProfileView({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(_customerContactsProvider(customer.id));
    final displayName = customer.displayName?.trim();
    final title = displayName?.isNotEmpty == true
        ? displayName!
        : customer.name;
    final subtitle = displayName?.isNotEmpty == true ? customer.name : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de cliente'),
        actions: [
          FilledButton.icon(
            onPressed: () => context.go('/sales/customers/${customer.id}/edit'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Header(customer: customer, title: title, subtitle: subtitle),
          const SizedBox(height: 16),
          _Alerts(customer: customer),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final left = _InfoColumn(customer: customer, contacts: contacts);
              final right = _SummaryColumn(customer: customer);
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [left, const SizedBox(height: 16), right],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 390, child: left),
                  const SizedBox(width: 16),
                  Expanded(child: right),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.customer,
    required this.title,
    required this.subtitle,
  });

  final Customer customer;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 30,
            child: Text(title.characters.first.toUpperCase()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      label: customer.isActive ? 'Activo' : 'Inactivo',
                      tone: customer.isActive
                          ? StatusTone.success
                          : StatusTone.danger,
                    ),
                    StatusChip(
                      label: customer.customerType == 'CREDIT'
                          ? 'Cliente credito'
                          : 'Cliente contado',
                      tone: customer.customerType == 'CREDIT'
                          ? StatusTone.warning
                          : StatusTone.neutral,
                    ),
                    StatusChip(
                      label: _documentPreferenceLabel(
                        customer.documentPreference,
                      ),
                      tone: StatusTone.neutral,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Alerts extends StatelessWidget {
  const _Alerts({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final alerts = <_ProfileAlert>[
      if (!customer.isActive)
        _ProfileAlert(
          icon: Icons.block,
          title: 'Cliente inactivo',
          message: customer.deactivationReason?.trim().isNotEmpty == true
              ? customer.deactivationReason!.trim()
              : 'No debe usarse para ventas nuevas sin reactivarlo.',
          color: Theme.of(context).colorScheme.errorContainer,
        ),
      if (customer.customerType == 'CREDIT' &&
          customer.creditLimit > 0 &&
          customer.currentBalance >= customer.creditLimit)
        _ProfileAlert(
          icon: Icons.credit_card_off_outlined,
          title: 'Sobre limite de credito',
          message:
              'Saldo ${_money(customer.currentBalance)} de limite ${_money(customer.creditLimit)}.',
          color: Theme.of(context).colorScheme.errorContainer,
        ),
    ];

    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final alert in alerts)
          SizedBox(
            width: 360,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: alert.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: Icon(alert.icon),
                title: Text(alert.title),
                subtitle: Text(alert.message),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoColumn extends ConsumerWidget {
  const _InfoColumn({required this.customer, required this.contacts});

  final Customer customer;
  final AsyncValue<List<CustomerContact>> contacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ProfileSection(
        title: 'Contacto y ubicacion',
        icon: Icons.contact_phone_outlined,
        children: [
          _InfoLine(
            'Telefono',
            displayPhone(customer.phone),
            empty: 'Sin telefono',
          ),
          _InfoLine('Correo', customer.email, empty: 'Sin correo'),
          _InfoLine('Provincia', customer.province, empty: 'Sin provincia'),
          _InfoLine('Gira', customer.gira, empty: 'Sin gira'),
          _InfoLine('Direccion', customer.address, empty: 'Sin direccion'),
        ],
      ),
      const SizedBox(height: 16),
      _ProfileSection(
        title: 'Fiscal y credito',
        icon: Icons.receipt_long_outlined,
        children: [
          _InfoLine(
            'Identificacion',
            customer.taxId,
            empty: 'Sin identificacion',
          ),
          ref
              .watch(identificationTypeDtosProvider)
              .when(
                loading: () =>
                    const _InfoLine('Tipo de identificacion', 'Cargando...'),
                error: (_, _) => const _InfoLine(
                  'Tipo de identificacion',
                  'No disponible',
                ),
                data: (types) => _InfoLine(
                  'Tipo de identificacion',
                  _identificationLabel(types, customer.identificationTypeId),
                  empty: 'Sin tipo',
                ),
              ),
          _InfoLine(
            'Actividad economica',
            customer.economicActivity,
            empty: 'Sin actividad',
          ),
          _InfoLine(
            'Factura electronica',
            customer.requiresEInvoice ? 'Si' : 'No',
          ),
          _InfoLine(
            'Documento habitual',
            _documentPreferenceLabel(customer.documentPreference),
          ),
          _InfoLine(
            'Condicion',
            customer.customerType == 'CREDIT'
                ? 'Credito ${customer.creditDays ?? 0} dias'
                : 'Contado',
          ),
          _InfoLine(
            'Limite de credito',
            customer.customerType == 'CREDIT'
                ? customer.creditLimit == 0
                      ? 'Sin limite'
                      : _money(customer.creditLimit)
                : 'No aplica',
          ),
        ],
      ),
      const SizedBox(height: 16),
      _ProfileSection(
        title: 'Contactos',
        icon: Icons.groups_outlined,
        children: [
          contacts.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) =>
                Text('No fue posible cargar contactos: $error'),
            data: (items) {
              if (items.isEmpty) {
                return const Text('Sin contactos registrados.');
              }
              return Column(
                children: [
                  for (final contact in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline),
                      title: Text(contact.name),
                      subtitle: Text(
                        [
                          if (contact.role?.trim().isNotEmpty == true)
                            contact.role!.trim(),
                          if (displayPhone(contact.phone).isNotEmpty)
                            displayPhone(contact.phone),
                          if (contact.birthday != null)
                            'Cumpleanos ${_dateText(contact.birthday!)}',
                        ].join(' · '),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ],
  );
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricCard(
            title: 'Saldo actual',
            value: _money(customer.currentBalance),
            icon: Icons.account_balance_wallet_outlined,
          ),
          _MetricCard(
            title: 'Disponible',
            value: customer.customerType != 'CREDIT'
                ? 'No aplica'
                : customer.creditLimit == 0
                ? 'Sin limite'
                : _money(customer.creditLimit - customer.currentBalance),
            icon: Icons.request_quote_outlined,
          ),
          _MetricCard(
            title: 'Ultima compra',
            value: 'Sin historial',
            icon: Icons.shopping_bag_outlined,
          ),
        ],
      ),
      const SizedBox(height: 16),
      _ProfileSection(
        title: 'Resumen comercial',
        icon: Icons.insights_outlined,
        children: const [
          _EmptyState(
            title: 'Sin resumen de compras todavia',
            message: 'Cuando existan documentos de venta, aqui apareceran ultima compra, productos frecuentes y actividad reciente.',
          ),
        ],
      ),
      const SizedBox(height: 16),
      _ProfileSection(
        title: 'Documentos',
        icon: Icons.folder_copy_outlined,
        children: const [
          DefaultTabController(
            length: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Pedidos'),
                    Tab(text: 'Facturas'),
                    Tab(text: 'Pagos'),
                    Tab(text: 'Devoluciones'),
                    Tab(text: 'Cotizaciones'),
                    Tab(text: 'Consignaciones'),
                  ],
                ),
                SizedBox(
                  height: 130,
                  child: TabBarView(
                    children: [
                      _DocumentEmpty(),
                      _DocumentEmpty(),
                      _DocumentEmpty(),
                      _DocumentEmpty(),
                      _DocumentEmpty(),
                      _DocumentEmpty(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value, {this.empty = 'Sin dato'});

  final String label;
  final String? value;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(text?.isNotEmpty == true ? text! : empty)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(message),
      ],
    ),
  );
}

class _DocumentEmpty extends StatelessWidget {
  const _DocumentEmpty();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Sin documentos para mostrar.'));
}

class _ProfileAlert {
  const _ProfileAlert({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
}

final _customerContactsProvider =
    FutureProvider.family<List<CustomerContact>, String>(
      (ref, customerId) =>
          ref.watch(customerApiProvider).getCustomerContacts(customerId),
    );

String _documentPreferenceLabel(String value) => switch (value) {
  'E_INVOICE' => 'Factura electronica',
  'TICKET' => 'Tiquete',
  'ASK_EACH_TIME' => 'Preguntar al facturar',
  _ => value,
};

/// Resuelve el tipo de identificacion guardado. Si el catalogo ya no lo tiene
/// (por ejemplo, se desactivo), se informa en lugar de fingir que no hay tipo.
String? _identificationLabel(List<IdentificationTypeDto> types, String? id) {
  if (id == null || id.isEmpty) return null;
  for (final type in types) {
    if (type.id == id) return type.name;
  }
  return 'No disponible';
}

String _money(double value) => value == 0 ? '0.00' : value.toStringAsFixed(2);

String _dateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
