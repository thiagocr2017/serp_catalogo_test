import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utilities/phone_number.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../configuration/configuration_module.dart';
import '../../api/customer_api.dart';
import '../../api/consignment_api.dart';
import '../../api/order_api.dart';
import '../../api/quote_api.dart';
import '../../api/return_api.dart';
import '../../api/sales_invoice_api.dart';

class CustomerProfilePage extends ConsumerWidget {
  const CustomerProfilePage({
    required this.customerId,
    this.returnTo,
    super.key,
  });

  final String customerId;
  final String? returnTo;

  String get _safeReturnTo {
    final value = returnTo;
    if (value != null) {
      final uri = Uri.tryParse(value);
      final internal =
          uri != null &&
          !uri.hasScheme &&
          uri.host.isEmpty &&
          value.startsWith('/');
      if (internal && RegExp(r'^/sales/quotes/[^/?]+$').hasMatch(uri.path)) {
        final nested = uri.queryParameters['returnTo'];
        if (nested == null ||
            nested == '/sales/quotes' ||
            RegExp(r'^/sales/customers/[^/?]+$').hasMatch(nested)) {
          return value;
        }
      }
      if (internal &&
          RegExp(r'^/sales/(invoices|returns|consignments)/[^/?]+$')
              .hasMatch(uri.path)) {
        return value;
      }
      if (value == '/sales/quotes') return value;
    }
    return '/sales/customers';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      FutureBuilder<CustomerDto?>(
        future: ref.read(customerApiProvider).getCustomerById(customerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
              appBar: AppBar(
                leading: _BackToCustomersAction(path: _safeReturnTo),
                title: const Text('Perfil de cliente'),
              ),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final customer = snapshot.data;
          if (customer == null) {
            return Scaffold(
              appBar: AppBar(
                leading: _BackToCustomersAction(path: _safeReturnTo),
                title: const Text('Perfil de cliente'),
              ),
              body: const Center(child: Text('El cliente no existe.')),
            );
          }
          return _CustomerProfileView(
            customer: customer,
            returnTo: _safeReturnTo,
          );
        },
      );
}

class _CustomerProfileView extends ConsumerWidget {
  const _CustomerProfileView({required this.customer, required this.returnTo});

  final CustomerDto customer;
  final String returnTo;

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
        leading: _BackToCustomersAction(path: returnTo),
        title: const Text('Perfil de cliente'),
        actions: [
          Semantics(
            button: true,
            label: 'Editar cliente ${customer.name}',
            child: FilledButton.icon(
              onPressed: () =>
                  context.go('/sales/customers/${customer.id}/edit'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
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

class _BackToCustomersAction extends StatelessWidget {
  const _BackToCustomersAction({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: path.startsWith('/sales/quotes/')
        ? 'Volver a cotización'
        : path.startsWith('/sales/returns/') ||
              path.startsWith('/sales/consignments/')
        ? 'Volver al documento'
        : 'Volver a clientes',
    onPressed: () => context.go(path),
    icon: const Icon(Icons.arrow_back),
  );
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.customer,
    required this.title,
    required this.subtitle,
  });

  final CustomerDto customer;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref
        .watch(customerCommercialSummaryProvider(customer.id))
        .value;

    return Semantics(
      label: 'Encabezado del perfil de cliente $title',
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
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
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
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
                        for (final name in {
                          ...customer.categoryNames,
                          if (summary != null)
                            ...summary.categories.map((c) => c.name),
                        })
                          StatusChip(label: name, tone: StatusTone.info),
                        if (summary != null)
                          for (final ranking in summary.commercialRankings)
                            StatusChip(
                              label: ranking,
                              tone: StatusTone.success,
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Alerts extends ConsumerWidget {
  const _Alerts({required this.customer});

  final CustomerDto customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(
      customerCommercialSummaryProvider(customer.id),
    );
    final summary = summaryAsync.value;
    final ordersAsync = ref.watch(ordersProvider);
    final quotesAsync = ref.watch(quotesProvider);
    final consignmentsAsync = ref.watch(consignmentsProvider);
    final returnsAsync = ref.watch(returnsProvider);
    final pendingDocumentsError = [
      ordersAsync.hasError,
      quotesAsync.hasError,
      consignmentsAsync.hasError,
      returnsAsync.hasError,
    ].contains(true);
    final pendingDocumentsLoading =
        ordersAsync.isLoading ||
        quotesAsync.isLoading ||
        consignmentsAsync.isLoading ||
        returnsAsync.isLoading;
    final pendingCount = pendingDocumentsError || pendingDocumentsLoading
        ? null
        : (ordersAsync.value ?? const <SalesOrderDto>[])
                  .where(
                    (doc) =>
                        _belongsToCustomer(
                          doc.customerId,
                          doc.customerName,
                          customer,
                        ) &&
                        {
                          OrderStatus.draft,
                          OrderStatus.confirmed,
                          OrderStatus.reserved,
                        }.contains(doc.status),
                  )
                  .length +
              (quotesAsync.value ?? const <SalesQuoteDto>[])
                  .where(
                    (doc) =>
                        _belongsToCustomer(
                          doc.customerId,
                          doc.customerName,
                          customer,
                        ) &&
                        {
                          QuoteStatus.draft,
                          QuoteStatus.sent,
                        }.contains(doc.status),
                  )
                  .length +
              (consignmentsAsync.value ?? const <SalesConsignmentDto>[])
                  .where(
                    (doc) =>
                        _belongsToCustomer(
                          doc.customerId,
                          doc.customerName,
                          customer,
                        ) &&
                        {
                          ConsignmentStatus.draft,
                          ConsignmentStatus.sent,
                          ConsignmentStatus.partialReturn,
                        }.contains(doc.status),
                  )
                  .length +
              (returnsAsync.value ?? const <SalesReturnDto>[])
                  .where(
                    (doc) =>
                        _belongsToCustomer(
                          doc.customerId,
                          doc.customerName,
                          customer,
                        ) &&
                        doc.status == ReturnStatus.draft,
                  )
                  .length;
    final alerts = <_ProfileAlert>[
      if (summary != null && summary.overdueInvoicesCount > 0)
        _ProfileAlert(
          icon: Icons.warning_amber_rounded,
          title: 'Credito vencido',
          message:
              '${summary.overdueInvoicesCount} factura(s) vencida(s) por un total de ${_money(summary.overdueInvoicesAmount)}.',
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
      if (!customer.isActive)
        _ProfileAlert(
          icon: Icons.block,
          title: 'Cliente inactivo',
          message: customer.deactivationReason?.trim().isNotEmpty == true
              ? customer.deactivationReason!.trim()
              : 'No debe usarse para ventas nuevas sin reactivarlo.',
          color: Theme.of(context).colorScheme.errorContainer,
        ),
      if (pendingDocumentsError ||
          pendingDocumentsLoading ||
          (pendingCount ?? 0) > 0)
        _ProfileAlert(
          icon: Icons.pending_actions_outlined,
          title: 'Documentos pendientes',
          message: pendingDocumentsError
              ? 'No se pudieron cargar los documentos relacionados. Abra para ver el error.'
              : pendingDocumentsLoading
              ? 'Consultando documentos relacionados...'
              : '$pendingCount documento(s) pendientes de procesar, despachar o liquidar.',
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          onTap: () => _showPendingDocuments(context, ref, customer),
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
            child: Semantics(
              label: 'Alerta: ${alert.title}. ${alert.message}',
              container: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: alert.color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: alert.onTap,
                    leading: Icon(alert.icon),
                    title: Text(alert.title),
                    subtitle: Text(alert.message),
                    trailing: alert.onTap == null
                        ? null
                        : const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoColumn extends ConsumerWidget {
  const _InfoColumn({required this.customer, required this.contacts});

  final CustomerDto customer;
  final AsyncValue<List<CustomerContactDto>> contacts;

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
          _InfoLine(
            'País',
            customer.countryCode == 'CR' ? 'Costa Rica' : customer.countryCode,
          ),
          _InfoLine('Provincia', customer.province, empty: 'Sin provincia'),
          _InfoLine('Ciudad / Distrito', customer.city, empty: 'Sin ciudad'),
          _InfoLine('Gira', customer.gira, empty: 'Sin gira'),
          _InfoLine('Direccion', customer.address, empty: 'Sin direccion'),
          _InfoLine(
            'Politica de envio',
            _shippingPolicyLabel(customer.shippingPaymentPolicy),
          ),
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
                error: (_, _) =>
                    const _InfoLine('Tipo de identificacion', 'No disponible'),
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

class _SummaryColumn extends ConsumerWidget {
  const _SummaryColumn({required this.customer});

  final CustomerDto customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(
      customerCommercialSummaryProvider(customer.id),
    );
    final summary = summaryAsync.value;
    final quotesAsync = ref.watch(quotesProvider);
    final customerQuotes =
        quotesAsync.value
            ?.where(
              (quote) => _belongsToCustomer(
                quote.customerId,
                quote.customerName,
                customer,
              ),
            )
            .toList() ??
        const <SalesQuoteDto>[];
    final ordersAsync = ref.watch(ordersProvider);
    final invoicesAsync = ref.watch(salesInvoicesProvider);
    final returnsAsync = ref.watch(returnsProvider);
    final consignmentsAsync = ref.watch(consignmentsProvider);
    final customerOrders =
        ordersAsync.value
            ?.where(
              (doc) => _belongsToCustomer(
                doc.customerId,
                doc.customerName,
                customer,
              ),
            )
            .toList() ??
        const <SalesOrderDto>[];
    final customerInvoices =
        invoicesAsync.value
            ?.where(
              (doc) => _belongsToCustomer(
                doc.customerId,
                doc.customerName,
                customer,
              ),
            )
            .toList() ??
        const <SalesInvoiceDto>[];
    final customerReturns =
        returnsAsync.value
            ?.where(
              (doc) => _belongsToCustomer(
                doc.customerId,
                doc.customerName,
                customer,
              ),
            )
            .toList() ??
        const <SalesReturnDto>[];
    final customerConsignments =
        consignmentsAsync.value
            ?.where(
              (doc) => _belongsToCustomer(
                doc.customerId,
                doc.customerName,
                customer,
              ),
            )
            .toList() ??
        const <SalesConsignmentDto>[];

    final lastPurchaseText = summary?.lastPurchaseAt != null
        ? _dateText(summary!.lastPurchaseAt!)
        : 'Sin historial';

    return Column(
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
              value: lastPurchaseText,
              icon: Icons.shopping_bag_outlined,
            ),
            if (summary != null && summary.totalInvoiced > 0)
              _MetricCard(
                title: 'Total facturado',
                value: _money(summary.totalInvoiced),
                icon: Icons.receipt_long_outlined,
              ),
          ],
        ),
        const SizedBox(height: 16),
        _ProfileSection(
          title: 'Resumen comercial',
          icon: Icons.insights_outlined,
          children: [
            if (summary == null ||
                (summary.lastPurchaseAt == null &&
                    summary.frequentProducts.isEmpty))
              const _EmptyState(
                title: 'Sin resumen de compras todavia',
                message: 'Cuando existan documentos de venta, aqui apareceran ultima compra, productos frecuentes y actividad reciente.',
              )
            else ...[
              if (summary.lastPurchaseAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Ultima compra: $lastPurchaseText',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              if (summary.frequentProducts.isNotEmpty) ...[
                Text(
                  'Productos frecuentes',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final prod in summary.frequentProducts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.star_outline, size: 20),
                    title: Text(prod.productName),
                    subtitle: Text(
                      '${prod.totalQuantity} unidades compradas en ${prod.purchaseCount} documento(s)',
                    ),
                  ),
              ],
            ],
          ],
        ),
        const SizedBox(height: 16),
        _ProfileSection(
          title: 'Documentos',
          icon: Icons.folder_copy_outlined,
          children: [
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
                    height: 148,
                    child: TabBarView(
                      children: [
                        _documentList(
                          context,
                          ordersAsync,
                          customerOrders,
                          emptyTitle: 'Sin pedidos',
                          emptyMessage:
                              'Los pedidos del cliente aparecerán aquí.',
                          number: (doc) => doc.orderNumber,
                          status: (doc) => _orderStatusLabel(doc.status),
                          amount: (doc) =>
                              '${doc.currencyCode} ${doc.totalAmount.toStringAsFixed(2)}',
                          onOpen: (_) => context.go(
                            '/sales/orders?customerId=${Uri.encodeQueryComponent(customer.id)}&customerName=${Uri.encodeQueryComponent(customer.name)}',
                          ),
                        ),
                        _documentList(
                          context,
                          invoicesAsync,
                          customerInvoices,
                          emptyTitle: 'Sin facturas',
                          emptyMessage: 'Las facturas emitidas para este cliente aparecerán aquí.',
                          number: (doc) => doc.invoiceNumber,
                          status: (doc) => _invoiceStatusLabel(doc.status),
                          amount: (doc) =>
                              '${doc.currencyCode} ${doc.totalAmount.toStringAsFixed(2)}',
                          onOpen: (doc) => context.go(
                            '/sales/invoices/${doc.id}?returnTo=${Uri.encodeQueryComponent('/sales/customers/${customer.id}')}',
                          ),
                          trailing: (doc) =>
                              doc.status == SalesInvoiceStatus.confirmed ||
                                  doc.status == SalesInvoiceStatus.paid
                              ? IconButton(
                                  tooltip: 'Iniciar devolución',
                                  icon: const Icon(
                                    Icons.assignment_return_outlined,
                                  ),
                                  onPressed: () => context.go(
                                    '/sales/returns/new?invoiceId=${Uri.encodeQueryComponent(doc.id)}&returnTo=${Uri.encodeQueryComponent('/sales/customers/${customer.id}')}',
                                  ),
                                )
                              : null,
                        ),
                        _DocumentEmpty(
                          title: 'Sin pagos registrados',
                          message:
                              'Los pagos aplicados al cliente apareceran aqui.',
                        ),
                        _documentList(
                          context,
                          returnsAsync,
                          customerReturns,
                          emptyTitle: 'Sin devoluciones',
                          emptyMessage:
                              'Las devoluciones del cliente aparecerán aquí.',
                          number: (doc) => doc.returnNumber,
                          status: (doc) => _returnStatusLabel(doc.status),
                          amount: (doc) =>
                              '${doc.currencyCode} ${doc.totalAmount.toStringAsFixed(2)}',
                          onOpen: (doc) => context.go(
                            '/sales/returns/${doc.id}?returnTo=${Uri.encodeQueryComponent('/sales/customers/${customer.id}')}',
                          ),
                        ),
                        quotesAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) => Center(
                            child: Text(
                              'No se pudieron cargar cotizaciones: $error',
                            ),
                          ),
                          data: (_) => customerQuotes.isEmpty
                              ? const _DocumentEmpty(
                                  title: 'Sin cotizaciones',
                                  message: 'Las cotizaciones del cliente aparecerán aquí.',
                                )
                              : ListView.builder(
                                  itemCount: customerQuotes.length,
                                  itemBuilder: (context, index) {
                                    final quote = customerQuotes[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(quote.quoteNumber),
                                      subtitle: Text(
                                        '${_quoteStatusLabel(quote.status)} · ${quote.currencyCode} ${quote.totalAmount.toStringAsFixed(2)}',
                                      ),
                                      trailing: PopupMenuButton<QuoteStatus>(
                                        tooltip: 'Cambiar estado de cotización',
                                        onSelected: (status) async {
                                          try {
                                            await ref
                                                .read(quoteApiProvider)
                                                .updateQuoteStatus(
                                                  quote.id,
                                                  status,
                                                );
                                            ref.invalidate(quotesProvider);
                                            ref.invalidate(
                                              customerCommercialSummaryProvider(
                                                customer.id,
                                              ),
                                            );
                                          } catch (error) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'No se pudo cambiar el estado: $error',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          if (quote.status == QuoteStatus.draft)
                                            const PopupMenuItem(
                                              value: QuoteStatus.sent,
                                              child: Text('Marcar enviada'),
                                            ),
                                          if (quote.status ==
                                                  QuoteStatus.draft ||
                                              quote.status ==
                                                  QuoteStatus.sent) ...[
                                            const PopupMenuItem(
                                              value: QuoteStatus.accepted,
                                              child: Text('Aceptar'),
                                            ),
                                            const PopupMenuItem(
                                              value: QuoteStatus.rejected,
                                              child: Text('Rechazar'),
                                            ),
                                          ],
                                        ],
                                        icon: const Icon(Icons.more_vert),
                                      ),
                                      onTap: () => context.go(
                                        '/sales/quotes/${quote.id}?returnTo=${Uri.encodeComponent('/sales/customers/${customer.id}')}',
                                      ),
                                    );
                                  },
                                ),
                        ),
                        _documentList(
                          context,
                          consignmentsAsync,
                          customerConsignments,
                          emptyTitle: 'Sin consignaciones',
                          emptyMessage:
                              'Las consignaciones del cliente aparecerán aquí.',
                          number: (doc) => doc.consignmentNumber,
                          status: (doc) => _consignmentStatusLabel(doc.status),
                          amount: (doc) =>
                              '${doc.currencyCode} ${doc.totalAmount.toStringAsFixed(2)}',
                          onOpen: (doc) => context.go(
                            '/sales/consignments/${doc.id}?returnTo=${Uri.encodeQueryComponent('/sales/customers/${customer.id}')}',
                          ),
                        ),
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
  Widget build(BuildContext context) => Semantics(
    label: 'Seccion $title',
    container: true,
    child: Card(
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
  Widget build(BuildContext context) => Semantics(
    label: '$title: $value',
    container: true,
    child: SizedBox(
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
  const _DocumentEmpty({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _ProfileAlert {
  const _ProfileAlert({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final VoidCallback? onTap;
}

bool _belongsToCustomer(
  String? customerId,
  String customerName,
  CustomerDto customer,
) =>
    customerId == customer.id ||
    (customerId == null &&
        customerName.trim().toLowerCase() ==
            customer.name.trim().toLowerCase());

Widget _documentList<T>(
  BuildContext context,
  AsyncValue<List<T>> async,
  List<T> documents, {
  required String emptyTitle,
  required String emptyMessage,
  required String Function(T) number,
  required String Function(T) status,
  required String Function(T) amount,
  required void Function(T) onOpen,
  Widget? Function(T)? trailing,
}) => async.when(
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, _) =>
      Center(child: Text('No se pudieron cargar documentos: $error')),
  data: (_) => documents.isEmpty
      ? _DocumentEmpty(title: emptyTitle, message: emptyMessage)
      : ListView.builder(
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final document = documents[index];
            return ListTile(
              dense: true,
              title: Text(number(document)),
              subtitle: Text('${status(document)} · ${amount(document)}'),
              trailing:
                  trailing?.call(document) ?? const Icon(Icons.chevron_right),
              onTap: () => onOpen(document),
            );
          },
        ),
);

Future<void> _showPendingDocuments(
  BuildContext context,
  WidgetRef ref,
  CustomerDto customer,
) async {
  final results = await Future.wait([
    ref
        .read(ordersProvider.future)
        .then<Object>((value) => value)
        .catchError((Object e) => e),
    ref
        .read(quotesProvider.future)
        .then<Object>((value) => value)
        .catchError((Object e) => e),
    ref
        .read(consignmentsProvider.future)
        .then<Object>((value) => value)
        .catchError((Object e) => e),
    ref
        .read(returnsProvider.future)
        .then<Object>((value) => value)
        .catchError((Object e) => e),
  ]);
  if (!context.mounted) return;
  final loadError = results
      .whereType<Object>()
      .where(
        (value) =>
            value is! List<SalesOrderDto> &&
            value is! List<SalesQuoteDto> &&
            value is! List<SalesConsignmentDto> &&
            value is! List<SalesReturnDto>,
      )
      .firstOrNull;
  if (loadError != null) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('No se pudieron cargar los pendientes'),
        content: Text(
          'Error al consultar los documentos del cliente: $loadError',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    return;
  }
  final orders = (results[0] as List<SalesOrderDto>)
      .where(
        (doc) =>
            _belongsToCustomer(doc.customerId, doc.customerName, customer) &&
            {
              OrderStatus.draft,
              OrderStatus.confirmed,
              OrderStatus.reserved,
            }.contains(doc.status),
      )
      .toList();
  final quotes = (results[1] as List<SalesQuoteDto>)
      .where(
        (doc) =>
            _belongsToCustomer(doc.customerId, doc.customerName, customer) &&
            {QuoteStatus.draft, QuoteStatus.sent}.contains(doc.status),
      )
      .toList();
  final consignments = (results[2] as List<SalesConsignmentDto>)
      .where(
        (doc) =>
            _belongsToCustomer(doc.customerId, doc.customerName, customer) &&
            {
              ConsignmentStatus.draft,
              ConsignmentStatus.sent,
              ConsignmentStatus.partialReturn,
            }.contains(doc.status),
      )
      .toList();
  final returns = (results[3] as List<SalesReturnDto>)
      .where(
        (doc) =>
            _belongsToCustomer(doc.customerId, doc.customerName, customer) &&
            doc.status == ReturnStatus.draft,
      )
      .toList();
  final rows =
      <
        ({
          String kind,
          String number,
          String status,
          String amount,
          VoidCallback open,
        })
      >[
        for (final doc in orders)
          (
            kind: 'Pedido',
            number: doc.orderNumber,
            status: _orderStatusLabel(doc.status),
            amount: '${doc.currencyCode} ${doc.totalAmount.toStringAsFixed(2)}',
            open: () => context.go(
              '/sales/orders?customerId=${Uri.encodeQueryComponent(customer.id)}&customerName=${Uri.encodeQueryComponent(customer.name)}',
            ),
          ),
        for (final doc in quotes)
          (
            kind: 'Cotización',
            number: doc.quoteNumber,
            status: _quoteStatusLabel(doc.status),
            amount: '${doc.currencyCode} ${doc.totalAmount.toStringAsFixed(2)}',
            open: () => context.go(
              '/sales/quotes/${doc.id}?returnTo=${Uri.encodeQueryComponent('/sales/customers/${customer.id}')}',
            ),
          ),
        for (final doc in consignments)
          (
            kind: 'Consignación',
            number: doc.consignmentNumber,
            status: _consignmentStatusLabel(doc.status),
            amount: '${doc.currencyCode} ${doc.totalAmount.toStringAsFixed(2)}',
            open: () => context.go(
              '/sales/consignments/${doc.id}?returnTo=${Uri.encodeQueryComponent('/sales/customers/${customer.id}')}',
            ),
          ),
        for (final doc in returns)
          (
            kind: 'Devolución',
            number: doc.returnNumber,
            status: _returnStatusLabel(doc.status),
            amount: '${doc.currencyCode} ${doc.totalAmount.toStringAsFixed(2)}',
            open: () => context.go(
              '/sales/returns/${doc.id}?returnTo=${Uri.encodeQueryComponent('/sales/customers/${customer.id}')}',
            ),
          ),
      ];
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Documentos pendientes'),
      content: SizedBox(
        width: 560,
        child: rows.isEmpty
            ? const Text(
                'No hay documentos pendientes para este cliente. El resumen se actualizará al recargar.',
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return ListTile(
                    leading: const Icon(Icons.pending_actions_outlined),
                    title: Text('${row.kind} · ${row.number}'),
                    subtitle: Text('${row.status} · ${row.amount}'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      row.open();
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

final _customerContactsProvider =
    FutureProvider.family<List<CustomerContactDto>, String>(
      (ref, customerId) =>
          ref.watch(customerApiProvider).getCustomerContacts(customerId),
    );

String _documentPreferenceLabel(String value) => switch (value) {
  'E_INVOICE' => 'Factura electronica',
  'TICKET' => 'Tiquete',
  'ASK_EACH_TIME' => 'Preguntar al facturar',
  _ => value,
};

String _shippingPolicyLabel(String value) => switch (value) {
  'PREPAID' => 'Pagado antes del envío',
  'CASH_ON_DELIVERY' => 'Cobro contra entrega',
  _ => 'Incluido en el precio',
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

String _quoteStatusLabel(QuoteStatus status) => switch (status) {
  QuoteStatus.draft => 'Borrador',
  QuoteStatus.sent => 'Enviada',
  QuoteStatus.accepted => 'Aceptada',
  QuoteStatus.rejected => 'Rechazada',
  QuoteStatus.expired => 'Expirada',
  QuoteStatus.converted => 'Convertida',
};

String _dateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _orderStatusLabel(OrderStatus status) => switch (status) {
  OrderStatus.draft => 'Borrador',
  OrderStatus.confirmed => 'Confirmado',
  OrderStatus.reserved => 'Reservado',
  OrderStatus.dispatched => 'Despachado',
  OrderStatus.delivered => 'Entregado',
  OrderStatus.cancelled => 'Cancelado',
};

String _invoiceStatusLabel(SalesInvoiceStatus status) => switch (status) {
  SalesInvoiceStatus.draft => 'Borrador',
  SalesInvoiceStatus.confirmed => 'Confirmada',
  SalesInvoiceStatus.cancelled => 'Cancelada',
  SalesInvoiceStatus.paid => 'Pagada',
};

String _returnStatusLabel(ReturnStatus status) => switch (status) {
  ReturnStatus.draft => 'Borrador',
  ReturnStatus.confirmed => 'Confirmada',
  ReturnStatus.cancelled => 'Cancelada',
};

String _consignmentStatusLabel(ConsignmentStatus status) => switch (status) {
  ConsignmentStatus.draft => 'Borrador',
  ConsignmentStatus.sent => 'Enviada',
  ConsignmentStatus.partialReturn => 'Devolución parcial',
  ConsignmentStatus.returned => 'Devuelta',
  ConsignmentStatus.settled => 'Liquidada',
  ConsignmentStatus.cancelled => 'Cancelada',
};
