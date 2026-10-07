import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/navigation/unsaved_changes_guard.dart';
import '../../../configuration/configuration_module.dart';
import '../../../inventory/inventory_module.dart';
import '../../../product/product_module.dart';
import '../../api/consignment_api.dart';
import '../../api/customer_api.dart';
import '../../api/order_api.dart';
import '../../api/quote_api.dart';
import '../../api/return_api.dart';
import '../../api/sales_api.dart';
import '../../api/sales_invoice_api.dart';

enum SalesDocumentKind { quote, order, invoice, returnItem, consignment }

class SalesDocumentFormPage extends ConsumerStatefulWidget {
  const SalesDocumentFormPage({
    required this.kind,
    this.quoteId,
    this.invoiceId,
    this.returnTo,
    super.key,
  });

  final SalesDocumentKind kind;
  final String? quoteId;
  final String? invoiceId;
  final String? returnTo;

  @override
  ConsumerState<SalesDocumentFormPage> createState() =>
      _SalesDocumentFormPageState();
}

class _SalesDocumentFormPageState extends ConsumerState<SalesDocumentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _exchangeRate = TextEditingController(text: '1');
  final _customerSearch = TextEditingController();
  final _generalDiscount = TextEditingController(text: '0');
  FocusNode? _productSearchFocus;
  TextEditingController? _productSearchController;
  final _quantityFocus = <String, FocusNode>{};
  final _reason = TextEditingController();
  final _invoiceSearch = TextEditingController();
  final _lines = <_DraftLine>[];
  late final Future<_FormData> _data = _loadData();
  CustomerDto? _customer;
  ProductSummaryDto? _productToAdd;
  List<ProductSummaryDto>? _returnProducts;
  String _productQuery = '';
  SalesInvoiceDto? _invoice;
  WarehouseDto? _warehouse;
  InventoryLocationDto? _location;
  SalesAgentDto? _agent;
  SalesQuoteDto? _quote;
  String? _hydratedQuoteId;
  DateTime? _validUntil;
  String? _error;
  late final String _returnCommandId = const Uuid().v4();
  bool _saving = false;
  bool _dirty = false;
  double? _appliedGeneralDiscount;
  SalesReturnPreviewDto? _returnPreview;
  ReturnFinancialResolution _returnResolution =
      ReturnFinancialResolution.refund;

  String get _title => switch (widget.kind) {
    SalesDocumentKind.quote =>
      widget.quoteId == null ? 'Nueva cotización' : 'Editar cotización',
    SalesDocumentKind.order => 'Nuevo pedido',
    SalesDocumentKind.invoice => 'Nueva factura de venta',
    SalesDocumentKind.returnItem => 'Nueva devolución',
    SalesDocumentKind.consignment => 'Nueva consignación',
  };

  String get _route => switch (widget.kind) {
    SalesDocumentKind.quote => '/sales/quotes',
    SalesDocumentKind.order => '/sales/orders',
    SalesDocumentKind.invoice => '/sales/invoices',
    SalesDocumentKind.returnItem => '/sales/returns',
    SalesDocumentKind.consignment => '/sales/consignments',
  };

  String? get _safeReturnTo {
    final value = widget.returnTo;
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.host.isNotEmpty ||
        !RegExp(
          r'^/sales/(quotes|invoices|returns|consignments)(/[^/?]+)?$|^/sales/customers/[^/?]+$',
        ).hasMatch(uri.path)) {
      return null;
    }
    return value;
  }

  bool get _needsWarehouse =>
      widget.kind == SalesDocumentKind.order ||
      widget.kind == SalesDocumentKind.invoice ||
      widget.kind == SalesDocumentKind.consignment;

  bool get _needsLocation =>
      widget.kind == SalesDocumentKind.order ||
      widget.kind == SalesDocumentKind.consignment;

  bool get _supportsDiscount =>
      widget.kind == SalesDocumentKind.quote ||
      widget.kind == SalesDocumentKind.order ||
      widget.kind == SalesDocumentKind.invoice;

  @override
  void dispose() {
    _notes.dispose();
    _exchangeRate.dispose();
    _customerSearch.dispose();
    _generalDiscount.dispose();
    for (final focus in _quantityFocus.values) {
      focus.dispose();
    }
    _reason.dispose();
    _invoiceSearch.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<_FormData> _loadData() async {
    final requests = <String, Future<dynamic>>{
      'products': ref
          .read(productApiProvider)
          .listProducts(const ProductListQuery(isActive: true)),
      'customers': ref.read(customerApiProvider).getCustomers(),
      if (widget.kind != SalesDocumentKind.returnItem)
        'settings': ref.read(configurationApiProvider).getBusinessSettings(),
      if (widget.kind == SalesDocumentKind.quote ||
          widget.kind == SalesDocumentKind.order ||
          widget.kind == SalesDocumentKind.consignment)
        'agents': ref
            .read(salesApiProvider)
            .getAgents(const SalesAgentQuery(activeOnly: true)),
      if (_needsWarehouse)
        'warehouses': ref.read(inventoryApiProvider).getWarehouses(),
      if (widget.kind == SalesDocumentKind.order)
        'quotes': ref.read(quoteApiProvider).getQuotes(),
      if (widget.quoteId != null)
        'editingQuote': ref
            .read(quoteApiProvider)
            .getQuoteById(widget.quoteId!),
      if (widget.kind == SalesDocumentKind.returnItem)
        'invoices': ref.read(salesInvoiceApiProvider).getInvoices(),
      if (widget.kind == SalesDocumentKind.returnItem)
        'returns': ref.read(returnApiProvider).getReturns(),
    };
    final values = await Future.wait(requests.values);
    final result = Map<String, dynamic>.fromIterables(requests.keys, values);
    return _FormData(
      customers: result['customers'] as List<CustomerDto>? ?? const [],
      products: result['products'] as List<ProductSummaryDto>,
      currency:
          (result['settings'] as BusinessSettingsDto?)?.defaultCurrency ?? '',
      agents: result['agents'] as List<SalesAgentDto>? ?? const [],
      warehouses: result['warehouses'] as List<WarehouseDto>? ?? const [],
      quotes: result['quotes'] as List<SalesQuoteDto>? ?? const [],
      invoices: result['invoices'] as List<SalesInvoiceDto>? ?? const [],
      returns: result['returns'] as List<SalesReturnDto>? ?? const [],
      editingQuote: result['editingQuote'] as SalesQuoteDto?,
    );
  }

  void _markDirty() {
    _dirty = true;
    UnsavedChangesGuard.instance.markDirty();
  }

  Future<void> _loadReturnPreview(String invoiceId) async {
    setState(() {
      _returnPreview = null;
      _returnProducts = null;
      _error = null;
    });
    try {
      final preview = await ref
          .read(returnApiProvider)
          .previewReturn(invoiceId);
      final products = await ref
          .read(productApiProvider)
          .listProducts(const ProductListQuery(isActive: true));
      if (mounted && _invoice?.id == invoiceId) {
        setState(() {
          _returnPreview = preview;
          _returnProducts = products;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'No se pudo validar la factura: $error');
      }
    }
  }

  Future<void> _leave() async {
    if (_saving) return;
    if (_dirty &&
        !await UnsavedChangesGuard.instance.confirmNavigation(context)) {
      return;
    }
    _dirty = false;
    UnsavedChangesGuard.instance.markClean();
    if (mounted) context.go(_safeReturnTo ?? _route);
  }

  void _addLine() {
    final product = _productToAdd;
    if (product == null) return;
    final existing = _lines
        .where((line) => line.product.id == product.id)
        .firstOrNull;
    if (existing != null && widget.kind == SalesDocumentKind.quote) {
      final quantity = int.tryParse(existing.quantity.text) ?? 0;
      final next = quantity + existing.quantityStep;
      setState(() {
        existing.quantity.text = '$next';
        _productToAdd = null;
        _productSearchController?.clear();
      });
      _markDirty();
      _focusQuantity(existing);
      return;
    }
    final invoiceLine = widget.kind == SalesDocumentKind.returnItem
        ? _invoice?.lines
              .where(
                (line) =>
                    !_lines.any((draft) => draft.invoiceLineId == line.id) &&
                    line.productId == product.id,
              )
              .firstOrNull
        : null;
    final draftLine = _DraftLine(
      product,
      invoiceLineId: invoiceLine?.id,
      price: widget.kind == SalesDocumentKind.returnItem
          ? invoiceLine?.unitPrice
          : null,
      maxQuantity: invoiceLine?.quantity,
      salePrice: product.unitPriceInCents / 100,
    );
    if (widget.kind == SalesDocumentKind.quote &&
        _appliedGeneralDiscount != null) {
      final effective = _requestedDiscount(product, _appliedGeneralDiscount!);
      draftLine.discount.text = _percent(effective);
      draftLine.lastValidDiscount = effective;
      draftLine.discountSource = _DiscountSource.general;
    }
    setState(() {
      _lines.add(draftLine);
      _productToAdd = null;
      _productSearchController?.clear();
    });
    _markDirty();
    if (widget.kind == SalesDocumentKind.quote) {
      _focusQuantity(_lines.last);
    }
  }

  void _focusQuantity(_DraftLine line) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_quantityFocus[line.product.id]);
      }
    });
  }

  List<ProductSummaryDto> _matchingProducts(_FormData data, String query) {
    final normalized = query.trim().toLowerCase();
    final products = _availableProducts(data);
    if (normalized.isEmpty) return products.take(10).toList();
    return products
        .where(
          (product) =>
              product.sku.toLowerCase().contains(normalized) ||
              product.name.toLowerCase().contains(normalized) ||
              product.description.toLowerCase().contains(normalized),
        )
        .take(10)
        .toList();
  }

  List<CustomerDto> _matchingCustomers(_FormData data, String query) {
    final normalized = query.trim().toLowerCase();
    return data.customers
        .where((customer) {
          if (!customer.isActive) return false;
          if (normalized.isEmpty) return true;
          return [
            customer.name,
            customer.displayName,
            customer.taxId,
            customer.phone,
            customer.email,
          ].whereType<String>().any(
            (value) => value.toLowerCase().contains(normalized),
          );
        })
        .take(10)
        .toList();
  }

  void _hydrateQuote(_FormData data, SalesQuoteDto quote) {
    _hydratedQuoteId = quote.id;
    _customer = data.customers
        .where((item) => item.id == quote.customerId)
        .firstOrNull;
    if (_customer != null) {
      _customerSearch.text = _customer!.displayName?.trim().isNotEmpty == true
          ? '${_customer!.displayName} · ${_customer!.name}'
          : _customer!.name;
    }
    _agent = data.agents.where((item) => item.id == quote.agentId).firstOrNull;
    _validUntil = quote.validUntil;
    _notes.text = quote.notes ?? '';
    for (final stored in quote.lines) {
      final product =
          data.products
              .where((item) => item.id == stored.productId)
              .firstOrNull ??
          ProductSummaryDto(
            id: stored.productId,
            sku: stored.productSku ?? '',
            name: stored.productName ?? 'Producto',
            description: '',
            currentStock: 0,
            unitPriceInCents: (stored.unitPrice * 100).round(),
            packagingPresentationName: stored.presentationName,
            unitsPerPresentation: stored.unitsPerPresentation,
          );
      final line = _DraftLine(
        product,
        quantity: stored.quantity,
        price: stored.unitPrice,
        salePrice: stored.unitPrice,
        initialDiscount: stored.discountPercent,
      )..hasManualDiscount = true;
      line.lastValidDiscount = stored.discountPercent;
      line.discountSource = _DiscountSource.manual;
      _lines.add(line);
    }
  }

  double _lineTotal(_DraftLine line) {
    final quantity = int.tryParse(line.quantity.text) ?? 0;
    final price = double.tryParse(line.price.text.replaceAll(',', '.')) ?? 0;
    final discount = _supportsDiscount
        ? (double.tryParse(line.discount.text.replaceAll(',', '.')) ?? 0)
        : 0;
    return quantity * price * (1 - discount / 100);
  }

  double get _total => _lines.fold(0, (sum, line) => sum + _lineTotal(line));

  String? _validateLine(_DraftLine line) {
    final quantity = int.tryParse(line.quantity.text);
    final price = double.tryParse(line.price.text.replaceAll(',', '.'));
    final discount = double.tryParse(line.discount.text.replaceAll(',', '.'));
    if (quantity == null || quantity < 1) {
      return 'La cantidad debe ser mayor que cero.';
    }
    if (widget.kind == SalesDocumentKind.quote &&
        quantity % line.product.unitsPerPresentation != 0) {
      return 'La cantidad debe ser múltiplo de ${line.product.unitsPerPresentation} '
          'unidades por presentación.';
    }
    if (line.maxQuantity != null && quantity > line.maxQuantity!) {
      return 'La cantidad no puede superar ${line.maxQuantity}.';
    }
    if (widget.kind == SalesDocumentKind.returnItem &&
        line.maxQuantity != null &&
        quantity != line.maxQuantity) {
      return 'La línea se devuelve por su cantidad facturada completa.';
    }
    if (price == null || price <= 0) {
      return 'El precio unitario debe ser mayor que cero.';
    }
    if (_supportsDiscount &&
        (discount == null || discount < 0 || discount > 100)) {
      return 'El descuento debe estar entre 0 y 100.';
    }
    if (widget.kind == SalesDocumentKind.quote &&
        line.product.promotionalPriceInCents != null &&
        discount! > line.promotionDiscountCap + 0.000001) {
      return 'El descuento máximo para esta promoción es '
          '${_percent(line.promotionDiscountCap)}%.';
    }
    return null;
  }

  String _stockLabel(ProductSummaryDto product) {
    if (product.currentStock <= 0) return 'Agotado';
    if (product.currentStock <= product.reorderPoint) {
      return 'Stock bajo · ${product.currentStock}';
    }
    return 'Disponible · ${product.currentStock}';
  }

  double _requestedDiscount(ProductSummaryDto product, double requested) {
    final promoPrice = product.promotionalPriceInCents;
    if (promoPrice == null || product.unitPriceInCents <= 0) return requested;
    final cap =
        ((product.unitPriceInCents - promoPrice) *
                100 /
                product.unitPriceInCents)
            .clamp(0, 100);
    return requested.clamp(0, cap).toDouble();
  }

  void _applyGeneralDiscount(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed < 0 || parsed > 100) {
      setState(
        () => _error = 'El descuento general debe estar entre 0 y 100%.',
      );
      return;
    }
    final capped = <String>[];
    setState(() {
      _error = null;
      _appliedGeneralDiscount = parsed;
      for (final line in _lines.where((line) => !line.hasManualDiscount)) {
        final effective = _requestedDiscount(line.product, parsed);
        if (effective + 0.000001 < parsed) capped.add(line.product.name);
        line.discount.text = _percent(effective);
        line.discountSource = _DiscountSource.general;
        line.lastValidDiscount = effective;
      }
      if (capped.isNotEmpty) {
        _error =
            'En productos promocionados se aplicó solo el máximo '
            'permitido: ${capped.join(', ')}.';
      }
      _markDirty();
    });
  }

  void _onLineDiscountChanged(_DraftLine line, String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed < 0 || parsed > 100) {
      setState(() => _error = 'El descuento debe estar entre 0 y 100%.');
      return;
    }
    if (line.product.promotionalPriceInCents != null &&
        parsed > line.promotionDiscountCap + 0.000001) {
      setState(() {
        _error =
            'El descuento máximo de ${line.product.name} es '
            '${_percent(line.promotionDiscountCap)}%. Se conserva el valor válido.';
      });
      line.discount.value = TextEditingValue(
        text: _percent(line.lastValidDiscount),
        selection: TextSelection.collapsed(
          offset: _percent(line.lastValidDiscount).length,
        ),
      );
      return;
    }
    line.lastValidDiscount = parsed;
    line.discountSource = _DiscountSource.manual;
    line.hasManualDiscount = true;
    setState(() {
      _error = null;
      _markDirty();
    });
  }

  String _percent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  Future<void> _save(_FormData data) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (widget.kind == SalesDocumentKind.returnItem) {
      if (_invoice == null) {
        setState(() => _error = 'Seleccione la factura de origen.');
        return;
      }
      if (_reason.text.trim().isEmpty) {
        setState(() => _error = 'Indique el motivo de la devolución.');
        return;
      }
    } else if (_customer == null) {
      setState(() => _error = 'Seleccione un cliente.');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'Agregue al menos un producto.');
      return;
    }
    for (final line in _lines) {
      final issue = _validateLine(line);
      if (issue != null) {
        setState(() => _error = issue);
        return;
      }
    }
    if (widget.kind != SalesDocumentKind.returnItem &&
        _customer?.isActive != true) {
      setState(() => _error = 'Seleccione un cliente activo.');
      return;
    }
    if (widget.kind == SalesDocumentKind.returnItem &&
        (_invoice?.customerId == null || _customer == null)) {
      setState(() => _error = 'La factura no tiene un cliente asociado.');
      return;
    }
    if (widget.kind == SalesDocumentKind.returnItem && _returnPreview == null) {
      setState(() => _error = 'Espere a que se valide la factura.');
      return;
    }
    if (widget.kind == SalesDocumentKind.returnItem &&
        _lines.any(
          (line) =>
              line.locationId == null ||
              (line.returnCondition == 'DAMAGED' &&
                  _returnPreview!.quarantineLocations.isEmpty),
        )) {
      setState(() => _error = 'Seleccione el destino de cada producto.');
      return;
    }
    if (_needsWarehouse && _warehouse == null) {
      setState(() => _error = 'Seleccione la bodega de salida.');
      return;
    }
    if (_needsLocation && _location == null) {
      setState(() => _error = 'Seleccione la ubicación de salida.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final rate = widget.kind == SalesDocumentKind.quote
          ? 1.0
          : double.parse(_exchangeRate.text.replaceAll(',', '.'));
      final customerName = _customer?.displayName?.trim().isNotEmpty == true
          ? _customer!.displayName!.trim()
          : _customer?.name ?? _invoice!.customerName;
      final savedRoute = _route;
      switch (widget.kind) {
        case SalesDocumentKind.quote:
          final api = ref.read(quoteApiProvider);
          final lines = [
            for (final line in _lines)
              QuoteLineInput(
                productId: line.product.id,
                quantity: int.parse(line.quantity.text),
                unitPrice: _number(line.price.text),
                discountPercent: _number(line.discount.text),
                productSku: line.product.sku,
                productName: line.product.name,
                presentationName: line.product.packagingPresentationName,
                unitsPerPresentation: line.product.unitsPerPresentation,
              ),
          ];
          if (widget.quoteId != null) {
            await api.updateQuote(
              id: widget.quoteId!,
              customerId: _customer!.id,
              customerName: customerName,
              validUntil: _validUntil,
              notes: _optional(_notes.text),
              agentId: _agent?.id,
              lines: lines,
            );
            ref.invalidate(quoteByIdProvider(widget.quoteId!));
          } else {
            await api.createQuote(
              customerId: _customer!.id,
              customerName: customerName,
              currencyCode: data.currency,
              exchangeRate: rate,
              validUntil: _validUntil,
              notes: _optional(_notes.text),
              agentId: _agent?.id,
              lines: lines,
            );
          }
          ref.invalidate(quotesProvider);
        case SalesDocumentKind.order:
          await ref
              .read(orderApiProvider)
              .createOrder(
                customerId: _customer!.id,
                customerName: customerName,
                currencyCode: data.currency,
                exchangeRate: rate,
                notes: _optional(_notes.text),
                agentId: _agent?.id,
                quoteId: _quote?.id,
                lines: [
                  for (final line in _lines)
                    OrderLineInput(
                      productId: line.product.id,
                      quantity: int.parse(line.quantity.text),
                      unitPrice: _number(line.price.text),
                      discountPercent: _number(line.discount.text),
                      productSku: line.product.sku,
                      productName: line.product.name,
                    ),
                ],
                warehouseId: _warehouse!.id,
                locationId: _location!.id,
              );
          ref.invalidate(ordersProvider);
        case SalesDocumentKind.invoice:
          await ref
              .read(salesInvoiceApiProvider)
              .createInvoice(
                customerId: _customer!.id,
                customerName: customerName,
                currencyCode: data.currency,
                exchangeRate: rate,
                notes: _optional(_notes.text),
                lines: [
                  for (final line in _lines)
                    SalesInvoiceLineInput(
                      productId: line.product.id,
                      quantity: int.parse(line.quantity.text),
                      unitPrice: _number(line.price.text),
                      discountPercent: _number(line.discount.text),
                      productSku: line.product.sku,
                      productName: line.product.name,
                    ),
                ],
                warehouseId: _warehouse!.id,
              );
          ref.invalidate(salesInvoicesProvider);
        case SalesDocumentKind.returnItem:
          final invoice = _invoice!;
          final result = await ref
              .read(returnApiProvider)
              .confirmReturn(
                ConfirmSalesReturnCommand(
                  commandId: _returnCommandId,
                  invoiceId: invoice.id,
                  reason: _reason.text.trim(),
                  resolution: _returnResolution,
                  lines: [
                    for (final line in _lines)
                      ReturnLineInput(
                        productId: line.product.id,
                        invoiceLineId: line.invoiceLineId!,
                        quantity: int.parse(line.quantity.text),
                        unitPrice: _number(line.price.text),
                        condition: line.returnCondition,
                        locationId: line.locationId,
                        productSku: line.product.sku,
                        productName: line.product.name,
                      ),
                  ],
                ),
              );
          ref.invalidate(returnsProvider);
          if (!mounted) return;
          _dirty = false;
          UnsavedChangesGuard.instance.markClean();
          context.go(
            '/sales/returns/${result.id}?returnTo=${Uri.encodeQueryComponent(_safeReturnTo ?? _route)}',
          );
          return;
        case SalesDocumentKind.consignment:
          await ref
              .read(consignmentApiProvider)
              .createConsignment(
                customerId: _customer!.id,
                customerName: customerName,
                currencyCode: data.currency,
                notes: _optional(_notes.text),
                agentId: _agent?.id,
                lines: [
                  for (final line in _lines)
                    ConsignmentLineInput(
                      productId: line.product.id,
                      quantity: int.parse(line.quantity.text),
                      unitPrice: _number(line.price.text),
                      productSku: line.product.sku,
                      productName: line.product.name,
                    ),
                ],
                warehouseId: _warehouse!.id,
                locationId: _location!.id,
              );
          ref.invalidate(consignmentsProvider);
      }
      _dirty = false;
      UnsavedChangesGuard.instance.markClean();
      if (mounted) context.go(_safeReturnTo ?? savedRoute);
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudo guardar: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty || _saving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: _leave,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Semantics(
          header: true,
          label: 'Formulario: $_title',
          child: Text(_title),
        ),
      ),
      body: FutureBuilder<_FormData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('No fue posible cargar: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final loaded = snapshot.data!;
          if (loaded.editingQuote != null &&
              _hydratedQuoteId != loaded.editingQuote!.id) {
            _hydrateQuote(loaded, loaded.editingQuote!);
          }
          if (widget.kind == SalesDocumentKind.returnItem &&
              widget.invoiceId != null &&
              _invoice == null) {
            _invoice = loaded.invoices
                .where((item) => item.id == widget.invoiceId)
                .firstOrNull;
            if (_invoice != null) {
              _customer = loaded.customers
                  .where((item) => item.id == _invoice!.customerId)
                  .firstOrNull;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _loadReturnPreview(_invoice!.id);
              });
            }
          }
          return _form(context, loaded);
        },
      ),
    ),
  );

  Widget _form(BuildContext context, _FormData data) {
    final customerQuotes = data.quotes
        .where(
          (quote) =>
              quote.status == QuoteStatus.accepted &&
              quote.customerId == _customer?.id,
        )
        .toList();
    final eligibleInvoices = data.invoices
        .where(
          (invoice) =>
              (invoice.status == SalesInvoiceStatus.confirmed ||
                  invoice.status == SalesInvoiceStatus.paid) &&
              _belongsToSelectedCustomer(invoice, data.customers) &&
              invoice.lines.any(
                (line) => !data.returns.any(
                  (item) =>
                      item.invoiceId == invoice.id &&
                      item.status != ReturnStatus.cancelled &&
                      item.lines.any(
                        (returned) => returned.invoiceLineId == line.id,
                      ),
                ),
              ),
        )
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 920;
        final editorContent = Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  MaterialBanner(
                    content: Text(_error!),
                    leading: const Icon(Icons.error_outline),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _error = null),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                _sectionTitle('Datos del documento'),
                const SizedBox(height: 12),
                if (widget.kind == SalesDocumentKind.returnItem)
                  _invoicePicker(eligibleInvoices, data.returns, data.customers)
                else if (widget.kind == SalesDocumentKind.quote)
                  _customerPicker(data)
                else
                  DropdownButtonFormField<CustomerDto>(
                    initialValue: _customer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cliente *',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final customer in data.customers.where(
                        (c) => c.isActive,
                      ))
                        DropdownMenuItem(
                          value: customer,
                          child: Text(
                            customer.displayName?.trim().isNotEmpty == true
                                ? '${customer.displayName} · ${customer.name}'
                                : customer.name,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _customer = value;
                      if (_quote?.customerId != value?.id) _quote = null;
                      _markDirty();
                    }),
                    validator: (value) =>
                        value == null ? 'Seleccione un cliente.' : null,
                  ),
                if (widget.kind == SalesDocumentKind.returnItem) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reason,
                    decoration: const InputDecoration(
                      labelText: 'Motivo de devolución *',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _markDirty(),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Indique el motivo.'
                        : null,
                  ),
                ],
                if (widget.kind != SalesDocumentKind.returnItem) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (widget.kind != SalesDocumentKind.quote)
                        SizedBox(
                          width: 210,
                          child: TextFormField(
                            controller: _exchangeRate,
                            decoration: InputDecoration(
                              labelText: 'Tipo de cambio *',
                              helperText: 'Moneda: ${data.currency}',
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            onChanged: (_) => _markDirty(),
                            validator: (value) {
                              final rate = double.tryParse(
                                (value ?? '').replaceAll(',', '.'),
                              );
                              return rate == null || rate <= 0
                                  ? 'Ingrese un tipo de cambio válido.'
                                  : null;
                            },
                          ),
                        ),
                      if (widget.kind == SalesDocumentKind.quote)
                        OutlinedButton.icon(
                          onPressed: _pickValidity,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            _validUntil == null
                                ? 'Definir vigencia'
                                : 'Válida hasta ${_formatDate(_validUntil!)}',
                          ),
                        ),
                      if (widget.kind == SalesDocumentKind.order &&
                          customerQuotes.isNotEmpty)
                        SizedBox(
                          width: 300,
                          child: DropdownButtonFormField<SalesQuoteDto>(
                            initialValue: _quote,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Cotización de origen',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final quote in customerQuotes)
                                DropdownMenuItem(
                                  value: quote,
                                  child: Text(quote.quoteNumber),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _quote = value;
                              _markDirty();
                            }),
                          ),
                        ),
                      if (widget.kind == SalesDocumentKind.quote ||
                          widget.kind == SalesDocumentKind.order ||
                          widget.kind == SalesDocumentKind.consignment)
                        SizedBox(
                          width: 260,
                          child: DropdownButtonFormField<SalesAgentDto>(
                            initialValue: _agent,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Agente',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final agent in data.agents)
                                DropdownMenuItem(
                                  value: agent,
                                  child: Text(agent.name),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _agent = value;
                              _markDirty();
                            }),
                          ),
                        ),
                    ],
                  ),
                ],
                if (_needsWarehouse) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 280,
                        child: DropdownButtonFormField<WarehouseDto>(
                          initialValue: _warehouse,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Bodega de salida *',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final warehouse in data.warehouses)
                              DropdownMenuItem(
                                value: warehouse,
                                child: Text(warehouse.name),
                              ),
                          ],
                          onChanged: (value) => setState(() {
                            _warehouse = value;
                            final activeLocations = value?.locations
                                .where((l) => l.isActive)
                                .toList();
                            _location =
                                activeLocations
                                    ?.where((location) => location.isDefault)
                                    .firstOrNull ??
                                activeLocations?.firstOrNull;
                            _markDirty();
                          }),
                          validator: (value) =>
                              value == null ? 'Seleccione una bodega.' : null,
                        ),
                      ),
                      if (_needsLocation)
                        SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<InventoryLocationDto>(
                            initialValue: _location,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Ubicación de salida *',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final location
                                  in _warehouse?.locations.where(
                                        (l) => l.isActive,
                                      ) ??
                                      const <InventoryLocationDto>[])
                                DropdownMenuItem(
                                  value: location,
                                  child: Text(
                                    '${location.code} · ${location.name}',
                                  ),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _location = value;
                              _markDirty();
                            }),
                            validator: (value) => value == null
                                ? 'Seleccione una ubicación.'
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                if (widget.kind == SalesDocumentKind.quote)
                  _productPicker(data, compact)
                else if (widget.kind == SalesDocumentKind.returnItem)
                  _invoice == null
                      ? const SizedBox.shrink()
                      : _returnInvoiceLines(data.returns)
                else
                  Row(
                    children: [
                      Expanded(
                        child: _sectionTitle(
                          widget.kind == SalesDocumentKind.returnItem
                              ? 'Productos de la factura'
                              : 'Productos',
                        ),
                      ),
                      SizedBox(
                        width: compact ? 220 : 320,
                        child: DropdownButtonFormField<ProductSummaryDto>(
                          initialValue: _productToAdd,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Agregar producto',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          items: [
                            for (final product in _availableProducts(data))
                              DropdownMenuItem(
                                value: product,
                                child: Text(
                                  '${product.sku} · ${product.name}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _productToAdd = value),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Agregar producto a las líneas',
                        onPressed: _productToAdd == null ? null : _addLine,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (widget.kind == SalesDocumentKind.quote) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 190,
                        child: TextField(
                          controller: _generalDiscount,
                          decoration: const InputDecoration(
                            labelText: 'Descuento general %',
                            helperText: 'No supera promociones',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          onChanged: (value) {
                            final parsed = double.tryParse(
                              value.replaceAll(',', '.'),
                            );
                            if (parsed != null &&
                                parsed >= 0 &&
                                parsed <= 100) {
                              _applyGeneralDiscount(value);
                            }
                          },
                          onSubmitted: _applyGeneralDiscount,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Aplicar descuento general',
                        onPressed: () =>
                            _applyGeneralDiscount(_generalDiscount.text),
                        icon: const Icon(Icons.done),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (_lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'Agregue al menos un producto para continuar.',
                      ),
                    ),
                  )
                else
                  for (var index = 0; index < _lines.length; index++)
                    _lineEditor(_lines[index], index, data.currency),
                const SizedBox(height: 20),
                if (widget.kind != SalesDocumentKind.returnItem)
                  TextFormField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notas',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _markDirty(),
                  ),
              ],
            ),
          ),
        );
        final summary = _summary(data);
        return Column(
          children: [
            Expanded(
              child: compact
                  ? ListView(children: [editorContent, summary])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 7,
                          child: SingleChildScrollView(child: editorContent),
                        ),
                        const VerticalDivider(width: 1),
                        SizedBox(
                          width: 310,
                          child: SingleChildScrollView(child: summary),
                        ),
                      ],
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _leave,
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _save(data),
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : widget.kind == SalesDocumentKind.returnItem
                          ? const Icon(Icons.assignment_return_outlined)
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _saving
                            ? 'Guardando…'
                            : widget.kind == SalesDocumentKind.quote
                            ? widget.quoteId == null
                                  ? 'Guardar borrador'
                                  : 'Guardar cambios'
                            : widget.kind == SalesDocumentKind.returnItem
                            ? 'Confirmar devolución'
                            : 'Guardar documento',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _belongsToSelectedCustomer(
    SalesInvoiceDto invoice,
    List<CustomerDto> customers,
  ) {
    if (invoice.customerId != null) {
      return customers.any((customer) => customer.id == invoice.customerId);
    }
    return customers.any(
      (customer) =>
          customer.name.trim().toLowerCase() ==
          invoice.customerName.trim().toLowerCase(),
    );
  }

  List<ProductSummaryDto> _availableProducts(_FormData data) {
    if (widget.kind != SalesDocumentKind.returnItem || _invoice == null) {
      return data.products;
    }
    final allowedIds = _invoice!.lines.map((line) => line.productId).toSet();
    return data.products
        .where(
          (product) =>
              allowedIds.contains(product.id) &&
              !_lines.any((line) => line.product.id == product.id),
        )
        .toList();
  }

  Widget _customerPicker(_FormData data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Autocomplete<CustomerDto>(
        displayStringForOption: (customer) =>
            customer.displayName?.trim().isNotEmpty == true
            ? '${customer.displayName} · ${customer.name}'
            : customer.name,
        optionsBuilder: (value) => _matchingCustomers(data, value.text),
        onSelected: (customer) => setState(() {
          _customer = customer;
          if (_quote?.customerId != customer.id) _quote = null;
          _customerSearch.text = customer.displayName?.trim().isNotEmpty == true
              ? '${customer.displayName} · ${customer.name}'
              : customer.name;
          _markDirty();
        }),
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          if (_customerSearch.text.isNotEmpty && controller.text.isEmpty) {
            controller.text = _customerSearch.text;
          }
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(
              labelText: 'Buscar cliente *',
              hintText: 'Nombre, identificación, teléfono o correo',
              prefixIcon: Icon(Icons.person_search_outlined),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _customerSearch.text = value;
              if (_customer != null && !value.contains(_customer!.name)) {
                setState(() => _customer = null);
              }
            },
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            child: SizedBox(
              width: 500,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final customer = options.elementAt(index);
                  return ListTile(
                    title: Text(
                      customer.displayName?.trim().isNotEmpty == true
                          ? customer.displayName!
                          : customer.name,
                    ),
                    subtitle: Text(
                      [
                        if (customer.displayName?.trim().isNotEmpty == true &&
                            customer.displayName != customer.name)
                          customer.name,
                        if (customer.taxId?.isNotEmpty == true) customer.taxId!,
                        if (customer.phone?.isNotEmpty == true) customer.phone!,
                        if (customer.email?.isNotEmpty == true) customer.email!,
                        customer.customerType == 'CREDIT'
                            ? 'Crédito'
                            : 'Contado',
                      ].join(' · '),
                    ),
                    onTap: () => onSelected(customer),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      if (_customer != null)
        ListTile(
          dense: true,
          leading: Icon(
            _customer!.isActive ? Icons.check_circle_outline : Icons.block,
            color: _customer!.isActive
                ? Colors.green
                : Theme.of(context).colorScheme.error,
          ),
          title: Text(
            _customer!.displayName?.trim().isNotEmpty == true
                ? _customer!.displayName!
                : _customer!.name,
          ),
          subtitle: Text(
            '${_customer!.isActive ? 'Activo' : 'Inactivo'} · ${_customer!.customerType == 'CREDIT' ? 'Crédito' : 'Contado'}${_customer!.phone == null ? '' : ' · ${_customer!.phone}'}${_customer!.email == null ? '' : ' · ${_customer!.email}'}',
          ),
        ),
    ],
  );

  List<SalesInvoiceLineDto> _returnableInvoiceLines(
    SalesInvoiceDto invoice,
    List<SalesReturnDto> returns,
  ) {
    final preview = _returnPreview;
    if (preview == null || preview.invoiceId != invoice.id) return const [];
    final activeReturns = returns
        .where(
          (item) =>
              item.invoiceId == invoice.id &&
              item.status != ReturnStatus.cancelled,
        )
        .toList();
    final previouslyReturnedLineIds = activeReturns
        .expand(
          (item) =>
              item.lines.map((line) => line.invoiceLineId).whereType<String>(),
        )
        .toSet();
    final legacyReturnedProductIds = activeReturns
        .expand((item) => item.lines)
        .where((line) => line.invoiceLineId == null)
        .map((line) => line.productId)
        .toSet();
    return invoice.lines
        .where(
          (line) =>
              (preview.availableQuantities[line.id] ?? 0) > 0 &&
              !previouslyReturnedLineIds.contains(line.id) &&
              !legacyReturnedProductIds.contains(line.productId),
        )
        .toList();
  }

  Widget _invoicePicker(
    List<SalesInvoiceDto> eligibleInvoices,
    List<SalesReturnDto> returns,
    List<CustomerDto> customers,
  ) {
    final query = _invoiceSearch.text.trim().toLowerCase();
    final filtered = eligibleInvoices.where((invoice) {
      if (query.isEmpty) return true;
      return <String>[
        invoice.invoiceNumber,
        invoice.customerName,
        ..._returnableInvoiceLines(
          invoice,
          returns,
        ).expand((line) => [line.productSku ?? '', line.productName ?? '']),
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _invoiceSearch,
          decoration: const InputDecoration(
            labelText: 'Buscar factura',
            hintText: 'Número, cliente, SKU o producto',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (eligibleInvoices.isEmpty)
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('No hay facturas elegibles'),
            subtitle: Text(
              'Se requieren facturas confirmadas con cliente y líneas.',
            ),
          )
        else if (filtered.isEmpty)
          const ListTile(title: Text('No hay coincidencias'))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final invoice = filtered[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    selected: _invoice?.id == invoice.id,
                    title: Text(invoice.invoiceNumber),
                    subtitle: Text(
                      '${invoice.customerName} · ${_returnableInvoiceLines(invoice, returns).length} líneas disponibles · ${invoice.currencyCode} ${invoice.totalAmount.toStringAsFixed(2)}',
                    ),
                    trailing: _invoice?.id == invoice.id
                        ? const Icon(Icons.check_circle_outline)
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      setState(() {
                        _invoice = invoice;
                        _customer = customers
                            .where(
                              (customer) => customer.id == invoice.customerId,
                            )
                            .firstOrNull;
                        _returnPreview = null;
                        for (final line in _lines) {
                          line.dispose();
                        }
                        _lines.clear();
                        _dirty = false;
                        UnsavedChangesGuard.instance.markClean();
                        _error = null;
                        _markDirty();
                      });
                      _loadReturnPreview(invoice.id);
                    },
                  ),
                );
              },
            ),
          ),
        if (_invoice != null) ...[
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text('Factura ${_invoice!.invoiceNumber}'),
            subtitle: Text(
              '${_invoice!.customerName} · ${_returnableInvoiceLines(_invoice!, returns).length} líneas disponibles · ${_invoice!.currencyCode} ${_invoice!.totalAmount.toStringAsFixed(2)}',
            ),
            trailing: TextButton.icon(
              onPressed: () => setState(() => _invoice = null),
              icon: const Icon(Icons.close),
              label: const Text('Cambiar'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _returnInvoiceLines(List<SalesReturnDto> returns) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Productos de la factura'),
      const SizedBox(height: 8),
      if (_returnPreview == null)
        const LinearProgressIndicator()
      else if (_returnPreview!.sellableLocations.isEmpty)
        const ListTile(
          leading: Icon(Icons.warning_amber_outlined),
          title: Text('Faltan ubicaciones de recepción'),
          subtitle: Text(
            'Configure una ubicación vendible y otra de cuarentena.',
          ),
        ),
      for (final line in _returnableInvoiceLines(_invoice!, returns))
        CheckboxListTile(
          value: _lines.any((draft) => draft.invoiceLineId == line.id),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(line.productName ?? line.productSku ?? line.productId),
          subtitle: Text(
            '${line.productSku ?? ''} · Facturadas: ${line.quantity} · Precio original: ${_invoice!.currencyCode} ${line.unitPrice.toStringAsFixed(2)}',
          ),
          secondary: Text(
            '${_invoice!.currencyCode} ${line.totalPrice.toStringAsFixed(2)}',
          ),
          onChanged: (selected) {
            setState(() {
              if (selected == true) {
                final product = _returnProducts
                    ?.where((p) => p.id == line.productId)
                    .firstOrNull;
                if (product == null) {
                  _error = 'No fue posible cargar el producto de esta línea.';
                  return;
                }
                _lines.add(
                  _DraftLine(
                    product,
                    invoiceLineId: line.id,
                    quantity: _returnPreview!.availableQuantities[line.id],
                    price: line.totalPrice / line.quantity,
                    maxQuantity: _returnPreview!.availableQuantities[line.id],
                    initialLocationId:
                        _returnPreview!.sellableLocations.firstOrNull?.id,
                    returnCondition: 'GOOD',
                  ),
                );
              } else {
                _lines.removeWhere((draft) {
                  if (draft.invoiceLineId != line.id) return false;
                  draft.dispose();
                  return true;
                });
              }
              _markDirty();
            });
          },
        ),
      const SizedBox(height: 12),
    ],
  );

  Widget _productPicker(_FormData data, bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: _sectionTitle('Líneas de cotización')),
          IconButton(
            tooltip: 'Agregar primer resultado',
            onPressed: () {
              final query = _productSearchController?.text ?? _productQuery;
              final matches = _matchingProducts(data, query);
              if (matches.isEmpty) return;
              setState(() => _productToAdd = matches.first);
              _addLine();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Autocomplete<ProductSummaryDto>(
        displayStringForOption: (product) => '${product.sku} · ${product.name}',
        optionsBuilder: (value) {
          _productQuery = value.text;
          return _matchingProducts(data, value.text);
        },
        onSelected: (product) {
          setState(() {
            _productToAdd = product;
          });
          _addLine();
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          _productSearchFocus = focusNode;
          _productSearchController = controller;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            decoration: const InputDecoration(
              labelText: 'Buscar producto',
              hintText: 'Código, nombre o descripción',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() {
              _productQuery = value;
              _productToAdd = null;
            }),
            onSubmitted: (_) => onSubmitted(),
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            child: SizedBox(
              width: compact ? 420 : 560,
              child: options.isEmpty
                  ? const ListTile(title: Text('Sin coincidencias'))
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final product = options.elementAt(index);
                        final highlighted =
                            AutocompleteHighlightedOption.of(context) == index;
                        return ListTile(
                          selected: highlighted,
                          title: Text('${product.sku} · ${product.name}'),
                          subtitle: Text(
                            '${product.description} · ${_money(product.unitPriceInCents / 100, data.currency)}${product.promotionalPriceInCents == null ? '' : ' · Promoción ${_money(product.promotionalPriceInCents! / 100, data.currency)}'}${product.packagePriceInCents == null ? '' : ' · Paquete ${_money(product.packagePriceInCents! / 100, data.currency)}'} · Venta: ${product.packagingPresentationName ?? 'Unidad'} · Mín. ${product.minimumSaleQuantity} · ${_stockLabel(product)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onSelected(product),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Moneda: ${data.currency} · Vigencia: ${_validUntil == null ? 'Sin definir' : _formatDate(_validUntil!)}',
      ),
    ],
  );

  Widget _lineEditor(_DraftLine line, int index, String currency) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${line.product.sku} · ${line.product.name}',
                  overflow: TextOverflow.ellipsis,
                ),
                if (line.product.packagingPresentationName?.isNotEmpty == true)
                  Text(
                    'Venta: ${line.product.packagingPresentationName} · Mín. ${line.product.minimumSaleQuantity}',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (widget.kind == SalesDocumentKind.quote &&
                    line.product.promotionalPriceInCents != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Promoción · ${_money(line.product.promotionalPriceInCents! / 100, currency)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                      Text(
                        'Máximo ${_percent(line.promotionDiscountCap)}% vs. precio normal',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                if (widget.kind == SalesDocumentKind.quote)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        line.product.currentStock <= 0
                            ? Icons.remove_shopping_cart_outlined
                            : line.product.currentStock <=
                                  line.product.reorderPoint
                            ? Icons.warning_amber_outlined
                            : Icons.inventory_2_outlined,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _stockLabel(line.product),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                if (line.product.packagePriceInCents != null)
                  Text(
                    'Paquete: ${_money(line.product.packagePriceInCents! / 100, '')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 170,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Restar ${line.quantityStep}',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.kind != SalesDocumentKind.quote
                      ? null
                      : () {
                          final current =
                              int.tryParse(line.quantity.text) ??
                              line.quantityStep;
                          final next = current - line.quantityStep;
                          if (next < line.quantityStep) return;
                          setState(() => line.quantity.text = '$next');
                          _markDirty();
                        },
                  icon: const Icon(Icons.remove, size: 18),
                ),
                Expanded(
                  child: TextField(
                    controller: line.quantity,
                    focusNode: widget.kind == SalesDocumentKind.quote
                        ? _quantityFocus.putIfAbsent(
                            line.product.id,
                            FocusNode.new,
                          )
                        : null,
                    decoration: InputDecoration(
                      labelText: line.maxQuantity == null
                          ? 'Cantidad'
                          : 'Cantidad (máx. ${line.maxQuantity})',
                      helperText:
                          widget.kind == SalesDocumentKind.quote &&
                              line.product.packagingPresentationName != null
                          ? '${line.product.packagingPresentationName}: ${line.quantityStep} unidades por incremento'
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    readOnly: widget.kind == SalesDocumentKind.returnItem,
                    onChanged: (_) => setState(_markDirty),
                    onSubmitted: widget.kind == SalesDocumentKind.quote
                        ? (_) => _productSearchFocus?.requestFocus()
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Sumar ${line.quantityStep}',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.kind != SalesDocumentKind.quote
                      ? null
                      : () {
                          final current = int.tryParse(line.quantity.text) ?? 0;
                          setState(
                            () => line.quantity.text =
                                '${current + line.quantityStep}',
                          );
                          _markDirty();
                        },
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: line.price,
              decoration: const InputDecoration(
                labelText: 'Precio unitario',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              readOnly: widget.kind == SalesDocumentKind.returnItem,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => setState(_markDirty),
            ),
          ),
          if (widget.kind == SalesDocumentKind.returnItem) ...[
            SizedBox(
              width: 155,
              child: DropdownButtonFormField<String>(
                initialValue: line.returnCondition,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Condición',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'GOOD', child: Text('Buen estado')),
                  DropdownMenuItem(value: 'DAMAGED', child: Text('Dañado')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    line.returnCondition = value;
                    final destinations = value == 'GOOD'
                        ? _returnPreview?.sellableLocations ?? const []
                        : _returnPreview?.quarantineLocations ?? const [];
                    line.locationId = destinations.firstOrNull?.id;
                    _markDirty();
                  });
                },
              ),
            ),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String>(
                initialValue: line.locationId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: line.returnCondition == 'GOOD'
                      ? 'Destino vendible'
                      : 'Destino cuarentena',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final location
                      in line.returnCondition == 'GOOD'
                          ? _returnPreview?.sellableLocations ?? const []
                          : _returnPreview?.quarantineLocations ?? const [])
                    DropdownMenuItem(
                      value: location.id,
                      child: Text(
                        '${location.code} · ${location.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  line.locationId = value;
                  _markDirty();
                }),
                validator: (value) =>
                    value == null ? 'Seleccione un destino compatible.' : null,
              ),
            ),
          ],
          if (_supportsDiscount)
            SizedBox(
              width: 110,
              child: TextField(
                controller: line.discount,
                decoration: const InputDecoration(
                  labelText: 'Desc. %',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: widget.kind == SalesDocumentKind.quote
                    ? (value) => _onLineDiscountChanged(line, value)
                    : (_) => setState(_markDirty),
              ),
            ),
          SizedBox(width: 110, child: Text(_money(_lineTotal(line), ''))),
          if (widget.kind == SalesDocumentKind.quote)
            SizedBox(
              width: 180,
              child: Text(
                _validateLine(line) ?? ' ',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          IconButton(
            tooltip: 'Quitar ${line.product.name}',
            onPressed: () => setState(() {
              _lines.removeAt(index).dispose();
              _markDirty();
            }),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    ),
  );

  Widget _summary(_FormData data) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionTitle('Resumen'),
        const SizedBox(height: 18),
        _summaryRow(
          'Cliente',
          widget.kind == SalesDocumentKind.returnItem
              ? _invoice?.customerName ?? 'Sin seleccionar'
              : _customer?.displayName ?? _customer?.name ?? 'Sin seleccionar',
        ),
        _summaryRow('Productos', '${_lines.length}'),
        if (widget.kind == SalesDocumentKind.quote) ...[
          _summaryRow('Descuento general', '${_generalDiscount.text}%'),
          _summaryRow('Subtotal', _money(_subtotal, data.currency)),
          _summaryRow('Descuento', _money(_discountTotal, data.currency)),
          _summaryRow('Estado', 'Borrador'),
        ],
        if (widget.kind == SalesDocumentKind.returnItem) ...[
          if (_returnPreview == null)
            const LinearProgressIndicator()
          else ...[
            _summaryRow(
              'Saldo pendiente',
              _money(
                _returnPreview!.outstandingAmount,
                _returnPreview!.currencyCode,
              ),
            ),
            _summaryRow(
              'Reducción de deuda',
              _money(
                _total < _returnPreview!.outstandingAmount
                    ? _total
                    : _returnPreview!.outstandingAmount,
                _returnPreview!.currencyCode,
              ),
            ),
            _summaryRow(
              'Excedente',
              _money(
                (_total - _returnPreview!.outstandingAmount).clamp(
                  0,
                  double.infinity,
                ),
                _returnPreview!.currencyCode,
              ),
            ),
            DropdownButtonFormField<ReturnFinancialResolution>(
              initialValue: _returnResolution,
              decoration: const InputDecoration(
                labelText: 'Resolver excedente',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: ReturnFinancialResolution.refund,
                  child: Text('Reembolso'),
                ),
                DropdownMenuItem(
                  value: ReturnFinancialResolution.customerCredit,
                  child: Text('Crédito del cliente'),
                ),
              ],
              onChanged: (value) => setState(() {
                if (value != null) _returnResolution = value;
                _markDirty();
              }),
            ),
            Text(
              _returnResolution == ReturnFinancialResolution.refund
                  ? 'El reembolso se valida contra los pagos confirmados.'
                  : 'El crédito se registra solo sobre dinero recibido.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
        const Divider(height: 28),
        Text('Total', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          _money(
            _total,
            widget.kind == SalesDocumentKind.returnItem
                ? _invoice?.currencyCode ?? data.currency
                : data.currency,
          ),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (widget.kind == SalesDocumentKind.returnItem)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'El RPC valida cantidades devueltas contra la factura.',
            ),
          ),
      ],
    ),
  );

  double get _subtotal => _lines.fold(0, (sum, line) {
    final quantity = int.tryParse(line.quantity.text) ?? 0;
    final price = double.tryParse(line.price.text.replaceAll(',', '.')) ?? 0;
    return sum + quantity * price;
  });

  double get _discountTotal => _subtotal - _total;

  Widget _sectionTitle(String text) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label)),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  Future<void> _pickValidity() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _validUntil = picked;
        _markDirty();
      });
    }
  }

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();
  double _number(String value) => double.parse(value.replaceAll(',', '.'));
  String _money(double value, String currency) =>
      '${currency.isEmpty ? '' : '$currency '}${value.toStringAsFixed(2)}';
  String _formatDate(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';
}

class _DraftLine {
  _DraftLine(
    this.product, {
    int? quantity,
    double? price,
    this.invoiceLineId,
    this.maxQuantity,
    double? salePrice,
    double? initialDiscount,
    this.returnCondition = 'GOOD',
    String? initialLocationId,
  }) : quantity = TextEditingController(
         text: '${quantity ?? _initialUnits(product)}',
       ),
       price = TextEditingController(
         text: (price ?? salePrice)?.toStringAsFixed(2) ?? '',
       ),
       discount = TextEditingController(text: '${initialDiscount ?? 0}') {
    locationId = initialLocationId;
    if (initialDiscount == null &&
        product.promotionalPriceInCents != null &&
        product.unitPriceInCents > 0) {
      discount.text = promotionDiscountCap.toStringAsFixed(2);
    }
    lastValidDiscount = double.tryParse(discount.text) ?? 0;
    discountSource = product.promotionalPriceInCents == null
        ? _DiscountSource.none
        : _DiscountSource.promotion;
  }

  final ProductSummaryDto product;
  final String? invoiceLineId;
  final int? maxQuantity;
  final TextEditingController quantity;
  final TextEditingController price;
  final TextEditingController discount;
  String returnCondition;
  String? locationId;
  late double lastValidDiscount;
  late _DiscountSource discountSource;
  bool hasManualDiscount = false;
  int get quantityStep => product.unitsPerPresentation;
  double get promotionDiscountCap =>
      product.promotionalPriceInCents == null || product.unitPriceInCents <= 0
      ? 0
      : ((product.unitPriceInCents - product.promotionalPriceInCents!) *
                100 /
                product.unitPriceInCents)
            .clamp(0, 100);

  void dispose() {
    quantity.dispose();
    price.dispose();
    discount.dispose();
  }

  static int _initialUnits(ProductSummaryDto product) {
    final factor = product.unitsPerPresentation < 1
        ? 1
        : product.unitsPerPresentation;
    final minimum = product.minimumSaleQuantity < factor
        ? factor
        : product.minimumSaleQuantity;
    return ((minimum + factor - 1) ~/ factor) * factor;
  }
}

enum _DiscountSource { none, promotion, general, manual }

class _FormData {
  const _FormData({
    required this.customers,
    required this.products,
    required this.currency,
    required this.agents,
    required this.warehouses,
    required this.quotes,
    required this.invoices,
    this.returns = const [],
    this.editingQuote,
  });

  final List<CustomerDto> customers;
  final List<ProductSummaryDto> products;
  final String currency;
  final List<SalesAgentDto> agents;
  final List<WarehouseDto> warehouses;
  final List<SalesQuoteDto> quotes;
  final List<SalesInvoiceDto> invoices;
  final List<SalesReturnDto> returns;
  final SalesQuoteDto? editingQuote;
}
