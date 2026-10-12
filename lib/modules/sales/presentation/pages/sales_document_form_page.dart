import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/navigation/unsaved_changes_guard.dart';
import '../../../../shared/utilities/search_query.dart';
import '../../../../shared/widgets/document_lines_grid.dart';
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

  String get _documentIntro => switch (widget.kind) {
    SalesDocumentKind.quote =>
      'Cliente, vigencia y responsable de la propuesta.',
    SalesDocumentKind.order =>
      'Cliente, moneda, origen de inventario y cotización relacionada.',
    SalesDocumentKind.invoice =>
      'Cliente, moneda y bodega desde la que saldrán los productos.',
    SalesDocumentKind.returnItem =>
      'Seleccione la factura confirmada y describa el motivo.',
    SalesDocumentKind.consignment =>
      'Cliente, responsable y origen de los productos consignados.',
  };

  String? get _safeReturnTo {
    final value = widget.returnTo;
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.host.isNotEmpty ||
        !RegExp(
          r'^/sales/(quotes|invoices|returns|consignments)(/[^/?]+)?$|^/sales/customers/[^/?]+$|^/sales/orders(/[^/?]+)?$',
        ).hasMatch(uri.path)) {
      return null;
    }
    return value;
  }

  bool get _needsWarehouse =>
      widget.kind == SalesDocumentKind.order ||
      widget.kind == SalesDocumentKind.invoice ||
      widget.kind == SalesDocumentKind.consignment;

  bool get _supportsDiscount =>
      widget.kind == SalesDocumentKind.quote ||
      widget.kind == SalesDocumentKind.order ||
      widget.kind == SalesDocumentKind.invoice;

  @override
  void dispose() {
    _notes.dispose();
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
      if (_needsWarehouse)
        'balances': ref.read(inventoryApiProvider).getLocationBalances(),
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
      taxPercentage:
          (result['settings'] as BusinessSettingsDto?)?.taxPercentage ?? '0',
      pricesIncludeTax:
          (result['settings'] as BusinessSettingsDto?)?.pricesIncludeTax ??
          false,
      agents: result['agents'] as List<SalesAgentDto>? ?? const [],
      warehouses: result['warehouses'] as List<WarehouseDto>? ?? const [],
      inventoryBalances:
          result['balances'] as List<InventoryBalanceDto>? ?? const [],
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

  void _addLine({bool keepSearchFocus = false}) {
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
      if (keepSearchFocus) {
        _focusProductSearch();
      } else {
        _focusQuantity(existing);
      }
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
    if (widget.kind == SalesDocumentKind.invoice &&
        draftLine.lastValidDiscount > _maximumLineDiscount(product)) {
      final maximum = _maximumLineDiscount(product);
      draftLine.discount.text = _percent(maximum);
      draftLine.lastValidDiscount = maximum;
    }
    if (_supportsDiscount &&
        _appliedGeneralDiscount != null &&
        product.promotionalPriceInCents == null) {
      final effective = _requestedDiscount(product, _appliedGeneralDiscount!);
      draftLine.discount.text = _percent(effective);
      draftLine.lastValidDiscount = effective;
      draftLine.discountSource = _DiscountSource.general;
    }
    final discountNotice =
        _appliedGeneralDiscount == null || _appliedGeneralDiscount == 0
        ? null
        : widget.kind == SalesDocumentKind.invoice &&
              product.promotionalPriceInCents == null
        ? 'La factura no permite descuento sin una promocion aprobada.'
        : product.promotionalPriceInCents != null
        ? 'Se conserva el descuento de la promocion; ajustelo manualmente en la linea si corresponde.'
        : null;
    setState(() {
      _error = discountNotice;
      _lines.add(draftLine);
      _productToAdd = null;
      _productSearchController?.clear();
    });
    _markDirty();
    if (keepSearchFocus) {
      _focusProductSearch();
    } else if (widget.kind == SalesDocumentKind.quote) {
      _focusQuantity(_lines.last);
    }
  }

  void _focusProductSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _productSearchFocus?.requestFocus();
    });
  }

  void _focusQuantity(_DraftLine line) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_quantityFocus[line.product.id]);
      }
    });
  }

  List<ProductSummaryDto> _matchingProducts(_FormData data, String query) {
    final normalized = effectiveSearchQuery(query).toLowerCase();
    final products = _availableProducts(data);
    if (normalized.isEmpty) return const [];
    return products
        .where(
          (product) =>
              product.sku.toLowerCase().contains(normalized) ||
              (product.barcode?.toLowerCase().contains(normalized) ?? false) ||
              product.name.toLowerCase().contains(normalized) ||
              product.description.toLowerCase().contains(normalized),
        )
        .take(10)
        .toList();
  }

  bool _hasExactProductCode(_FormData data, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return _matchingProducts(data, query).any(
      (product) =>
          product.sku.trim().toLowerCase() == normalized ||
          product.barcode?.trim().toLowerCase() == normalized,
    );
  }

  List<CustomerDto> _matchingCustomers(_FormData data, String query) {
    final normalized = effectiveSearchQuery(query).toLowerCase();
    if (normalized.isEmpty) return const [];
    return data.customers
        .where((customer) {
          if (!customer.isActive) return false;
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
        : 0.0;
    return calculateDocumentLineSubtotal(
      quantity: quantity,
      unitPrice: price,
      discountPercent: discount,
    );
  }

  void _addFirstMatchingProduct(
    _FormData data, {
    bool exactOnly = false,
    bool keepSearchFocus = false,
  }) {
    final query = (_productSearchController?.text ?? _productQuery).trim();
    final products = _matchingProducts(data, query);
    final normalized = query.toLowerCase();
    final product = exactOnly
        ? products.where((item) {
            return item.sku.trim().toLowerCase() == normalized ||
                item.barcode?.trim().toLowerCase() == normalized;
          }).firstOrNull
        : products.firstOrNull;
    if (product == null) return;
    _productToAdd = product;
    _addLine(keepSearchFocus: keepSearchFocus);
  }

  double get _total => _lines.fold(0, (sum, line) => sum + _lineTotal(line));

  String? _validateLine(_DraftLine line, _FormData data) {
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
    if (_needsWarehouse) {
      final available = _availableStock(data, line.product);
      if (available <= 0) {
        return 'El producto no tiene stock vendible en el origen seleccionado.';
      }
      final totalRequested = _lines
          .where((candidate) => candidate.product.id == line.product.id)
          .fold<int>(
            0,
            (sum, candidate) =>
                sum + (int.tryParse(candidate.quantity.text) ?? 0),
          );
      if (totalRequested > available) {
        return 'Solo hay $available unidades disponibles en el origen seleccionado.';
      }
    }
    if (widget.kind == SalesDocumentKind.returnItem) {
      final damaged = int.tryParse(line.damagedQuantity.text);
      if (damaged == null || damaged < 0 || damaged > quantity) {
        return 'Las unidades dañadas deben estar entre 0 y $quantity.';
      }
      if (damaged > 0 && line.conditionNote.text.trim().isEmpty) {
        return 'Escriba una nota para describir las unidades dañadas.';
      }
    }
    if (price == null || price <= 0) {
      return 'El precio unitario debe ser mayor que cero.';
    }
    if (_supportsDiscount && (discount == null || discount < 0)) {
      return 'El descuento no puede ser negativo.';
    }
    if (_supportsDiscount &&
        discount! > _maximumLineDiscount(line.product) + 0.000001) {
      return 'El descuento máximo permitido para ${line.product.name} es '
          '${_percent(_maximumLineDiscount(line.product))}%.';
    }
    return null;
  }

  int _availableStock(_FormData data, ProductSummaryDto product) {
    if (!_needsWarehouse || _warehouse == null) return 0;
    final sellableLocationIds = _warehouse!.locations
        .where(
          (location) => location.isActive && location.stockRole == 'SELLABLE',
        )
        .map((location) => location.id)
        .toSet();
    return data.inventoryBalances
        .where(
          (balance) =>
              balance.productId == product.id &&
              balance.warehouseId == _warehouse!.id &&
              sellableLocationIds.contains(balance.locationId),
        )
        .fold(0, (sum, balance) => sum + balance.availableQuantity);
  }

  String _stockLabel(ProductSummaryDto product, _FormData data) {
    final quantity = _needsWarehouse
        ? _availableStock(data, product)
        : product.currentStock;
    if (quantity <= 0) return 'Agotado';
    if (quantity <= product.reorderPoint) return 'Stock bajo · $quantity';
    return 'Disponible · $quantity';
  }

  double _requestedDiscount(ProductSummaryDto product, double requested) {
    return requested.clamp(0, _maximumLineDiscount(product)).toDouble();
  }

  double _maximumLineDiscount(ProductSummaryDto product) {
    if (product.promotionalPriceInCents == null ||
        product.unitPriceInCents <= 0) {
      return widget.kind == SalesDocumentKind.invoice ? 0 : 100;
    }
    final promotionCap =
        ((product.unitPriceInCents - product.promotionalPriceInCents!) *
                100 /
                product.unitPriceInCents)
            .clamp(0, 100);
    if (widget.kind != SalesDocumentKind.invoice) {
      return promotionCap.toDouble();
    }
    return (promotionCap.clamp(0, 99.99) * 100).floorToDouble() / 100;
  }

  void _applyGeneralDiscount(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed < 0 || parsed > 100) {
      setState(
        () => _error = 'El descuento general debe estar entre 0 y 100%.',
      );
      return;
    }
    final skipped = <String>[];
    setState(() {
      _error = null;
      _appliedGeneralDiscount = parsed;
      for (final line in _lines.where((line) => !line.hasManualDiscount)) {
        if (line.product.promotionalPriceInCents != null) continue;
        final effective = _requestedDiscount(line.product, parsed);
        if (effective + 0.000001 < parsed) skipped.add(line.product.name);
        line.discount.text = _percent(effective);
        line.discountSource = _DiscountSource.general;
        line.lastValidDiscount = effective;
      }
      if (skipped.isNotEmpty) {
        _error =
            'El descuento general no se aplicó a ${skipped.join(', ')}: '
            'la factura solo permite el descuento de una promoción aprobada.';
      } else if (_lines.any(
        (line) => line.product.promotionalPriceInCents != null,
      )) {
        _error =
            'Se conservó el descuento aprobado de las promociones. '
            'Para cambiarlo, edite el descuento de esa línea; no se acumulan.';
      }
      _markDirty();
    });
  }

  void _onLineDiscountChanged(_DraftLine line, String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed < 0) {
      setState(() => _error = 'El descuento no puede ser negativo.');
      return;
    }
    final maximum = _maximumLineDiscount(line.product);
    if (parsed > maximum + 0.000001) {
      setState(() {
        _error =
            'El descuento máximo de ${line.product.name} es '
            '${_percent(maximum)}%. Se conserva el valor válido.';
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
      final issue = _validateLine(line, data);
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
          (line) => (int.tryParse(line.damagedQuantity.text) ?? 0) > 0,
        ) &&
        _returnPreview!.quarantineLocations.isEmpty) {
      setState(
        () => _error =
            'No hay una ubicación de cuarentena configurada para esta bodega.',
      );
      return;
    }
    if (_needsWarehouse && _warehouse == null) {
      setState(() => _error = 'Seleccione la bodega de salida.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // The current Sales API retains this legacy argument. Sales documents
      // use the configured reference currency; conversion belongs to Payments.
      const rate = 1.0;
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
                locationId: null,
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
                    for (final line in _lines) ...[
                      if (int.parse(line.quantity.text) -
                              int.parse(line.damagedQuantity.text) >
                          0)
                        ReturnLineInput(
                          productId: line.product.id,
                          invoiceLineId: line.invoiceLineId!,
                          quantity:
                              int.parse(line.quantity.text) -
                              int.parse(line.damagedQuantity.text),
                          unitPrice: _number(line.price.text),
                          condition: 'GOOD',
                          conditionNote: null,
                          productSku: line.product.sku,
                          productName: line.product.name,
                        ),
                      if (int.parse(line.damagedQuantity.text) > 0)
                        ReturnLineInput(
                          productId: line.product.id,
                          invoiceLineId: line.invoiceLineId!,
                          quantity: int.parse(line.damagedQuantity.text),
                          unitPrice: _number(line.price.text),
                          condition: 'DAMAGED',
                          conditionNote: line.conditionNote.text.trim(),
                          productSku: line.product.sku,
                          productName: line.product.name,
                        ),
                    ],
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
                locationId: null,
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
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              widget.kind == SalesDocumentKind.returnItem
                                  ? Icons.assignment_return_outlined
                                  : Icons.description_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionTitle('Datos del documento'),
                                  Text(
                                    _documentIntro,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (data.currency.isNotEmpty &&
                                widget.kind != SalesDocumentKind.returnItem)
                              Tooltip(
                                message: 'Moneda del documento',
                                child: Chip(
                                  avatar: const Icon(Icons.payments_outlined),
                                  label: Text(data.currency),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (widget.kind == SalesDocumentKind.returnItem)
                          _invoicePicker(
                            eligibleInvoices,
                            data.returns,
                            data.customers,
                          )
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
                                    customer.displayName?.trim().isNotEmpty ==
                                            true
                                        ? '${customer.displayName} · ${customer.name}'
                                        : customer.name,
                                  ),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _customer = value;
                              if (_quote?.customerId != value?.id) {
                                _quote = null;
                              }
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
                            validator: (value) =>
                                value == null || value.trim().isEmpty
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
                              if (widget.kind == SalesDocumentKind.quote)
                                OutlinedButton.icon(
                                  onPressed: _pickValidity,
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                  ),
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
                          Row(
                            children: [
                              Icon(
                                Icons.warehouse_outlined,
                                size: 20,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Bodega de salida',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
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
                                    _productToAdd = null;
                                    _productQuery = '';
                                    _productSearchController?.clear();
                                    _markDirty();
                                  }),
                                  validator: (value) => value == null
                                      ? 'Seleccione una bodega.'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.kind == SalesDocumentKind.quote ||
                    widget.kind == SalesDocumentKind.invoice)
                  _generalDiscountControl(),
                if (widget.kind == SalesDocumentKind.returnItem)
                  _invoice == null
                      ? const SizedBox.shrink()
                      : _returnInvoiceLines(data)
                else
                  _productPicker(data, compact),
                if (widget.kind == SalesDocumentKind.returnItem) ...[
                  const SizedBox(height: 10),
                  if (_lines.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.add_shopping_cart_outlined),
                      title: Text('Seleccione líneas de la factura'),
                    )
                  else
                    DocumentLinesGrid(
                      searchField: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Factura de origen',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        child: Text(_invoice!.invoiceNumber),
                      ),
                      focusSearch: () {},
                      columns: _lineColumns(data),
                      rowCount: _lines.length,
                      rowBuilder: (index, selected, select) => _lineCells(
                        _lines[index],
                        index,
                        data,
                        select: select,
                      ),
                      onAddLine: () {},
                      addLineEnabled: false,
                      showCaptureControls: false,
                      onRemoveLine: (index) => setState(() {
                        _lines.removeAt(index).dispose();
                        _markDirty();
                      }),
                      emptyState: const SizedBox.shrink(),
                      footerLabel: 'Puede devolver las unidades pendientes en varios documentos. Las buenas vuelven a su origen; las dañadas requieren nota y van a cuarentena.',
                    ),
                ],
                if (widget.kind == SalesDocumentKind.returnItem)
                  for (final line in _lines.where(
                    (line) => line.invoiceLineId != null,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: line.conditionNote,
                        minLines: 1,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText:
                              'Nota de daño: ${line.product.name}${(int.tryParse(line.damagedQuantity.text) ?? 0) > 0 ? ' *' : ''}',
                          hintText: 'Obligatoria cuando hay unidades dañadas',
                          isDense: true,
                        ),
                        onChanged: (_) => setState(_markDirty),
                      ),
                    ),
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
                            : switch (widget.kind) {
                                SalesDocumentKind.quote =>
                                  widget.quoteId == null
                                      ? 'Guardar borrador'
                                      : 'Guardar cambios',
                                SalesDocumentKind.order => 'Guardar pedido',
                                SalesDocumentKind.invoice => 'Guardar factura',
                                SalesDocumentKind.returnItem =>
                                  'Confirmar devolución',
                                SalesDocumentKind.consignment =>
                                  'Guardar consignación',
                              },
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
    if (_needsWarehouse) {
      if (_warehouse == null) return const [];
      return data.products
          .where((product) => _availableStock(data, product) > 0)
          .toList();
    }
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
                ? Theme.of(context).colorScheme.primary
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
    final legacyReturnedProductIds = activeReturns
        .expand((item) => item.lines)
        .where((line) => line.invoiceLineId == null)
        .map((line) => line.productId)
        .toSet();
    return invoice.lines
        .where(
          (line) =>
              (preview.availableQuantities[line.id] ?? 0) > 0 &&
              !legacyReturnedProductIds.contains(line.productId),
        )
        .toList();
  }

  Widget _invoicePicker(
    List<SalesInvoiceDto> eligibleInvoices,
    List<SalesReturnDto> returns,
    List<CustomerDto> customers,
  ) {
    final query = effectiveSearchQuery(_invoiceSearch.text).toLowerCase();
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

  Widget _returnInvoiceLines(_FormData data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle('Productos de la factura'),
      const SizedBox(height: 8),
      if (_returnPreview == null)
        const LinearProgressIndicator()
      else if (_returnPreview!.sellableLocations.isEmpty)
        const ListTile(
          leading: Icon(Icons.warning_amber_outlined),
          title: Text('La factura no tiene ubicaciones de salida trazables'),
          subtitle: Text(
            'No se puede confirmar una devolución sin conocer el origen del inventario.',
          ),
        ),
      for (final line in _returnableInvoiceLines(_invoice!, data.returns))
        CheckboxListTile(
          value: _lines.any((draft) => draft.invoiceLineId == line.id),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(line.productName ?? line.productSku ?? line.productId),
          subtitle: Text(
            '${line.productSku ?? ''} · Facturadas: ${line.quantity} · Devueltas: ${_returnPreview!.returnedQuantities[line.id] ?? 0} · Pendientes: ${_returnPreview!.availableQuantities[line.id] ?? 0} · Precio original: ${_invoice!.currencyCode} ${line.unitPrice.toStringAsFixed(2)}',
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

  Widget _generalDiscountControl() => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _generalDiscount,
            decoration: InputDecoration(
              labelText: 'Descuento general %',
              helperText: widget.kind == SalesDocumentKind.invoice
                  ? 'Factura: solo se acepta la promoción aprobada por producto'
                  : 'No reemplaza promociones ni líneas editadas',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (value) {
              final parsed = double.tryParse(value.replaceAll(',', '.'));
              if (parsed != null && parsed >= 0 && parsed <= 100) {
                _applyGeneralDiscount(value);
              }
            },
            onSubmitted: _applyGeneralDiscount,
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Aplicar descuento general',
          onPressed: () => _applyGeneralDiscount(_generalDiscount.text),
          icon: const Icon(Icons.done),
        ),
      ],
    ),
  );

  Widget _productPicker(_FormData data, bool compact) {
    final title = switch (widget.kind) {
      SalesDocumentKind.quote => 'Productos de la cotización',
      SalesDocumentKind.order => 'Productos del pedido',
      SalesDocumentKind.invoice => 'Productos de la factura',
      SalesDocumentKind.returnItem => 'Productos de la factura',
      SalesDocumentKind.consignment => 'Productos para consignar',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(title)),
            Text(
              '${_lines.length} líneas · ${_lines.fold<int>(0, (sum, line) => sum + (int.tryParse(line.quantity.text) ?? 0))} unidades',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        DocumentLinesGrid(
          searchField: _productSearchField(data, compact),
          focusSearch: () => _productSearchFocus?.requestFocus(),
          columns: _lineColumns(data),
          rowCount: _lines.length,
          rowBuilder: (index, selected, select) =>
              _lineCells(_lines[index], index, data, select: select),
          onAddLine: () => _productSearchFocus?.requestFocus(),
          onRemoveLine: (index) => setState(() {
            _lines.removeAt(index).dispose();
            _markDirty();
          }),
          emptyState: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.add_shopping_cart_outlined),
              title: Text('Aún no hay productos'),
              subtitle: Text('Busque por SKU, código de barras o nombre.'),
            ),
          ),
        ),
        if (_needsWarehouse &&
            effectiveSearchQuery(_productQuery).length >= 3 &&
            _matchingProducts(data, _productQuery).isEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(
              _warehouse == null
                  ? 'Seleccione una bodega para buscar.'
                  : 'No hay stock vendible en el origen seleccionado.',
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Moneda: ${data.currency} · Vigencia: ${_validUntil == null ? 'Sin definir' : _formatDate(_validUntil!)} · IVA ${data.taxPercentage}% ${data.pricesIncludeTax ? 'incluido' : 'configurado'} (informativo)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _productSearchField(
    _FormData data,
    bool compact,
  ) => Autocomplete<ProductSummaryDto>(
    displayStringForOption: (product) => '${product.sku} · ${product.name}',
    optionsBuilder: (value) {
      _productQuery = value.text;
      return _matchingProducts(data, value.text);
    },
    onSelected: (product) {
      setState(() => _productToAdd = product);
      _addLine();
    },
    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
      _productSearchFocus = focusNode;
      _productSearchController = controller;
      return Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.tab &&
              _hasExactProductCode(data, controller.text)) {
            _addFirstMatchingProduct(
              data,
              exactOnly: true,
              keepSearchFocus: true,
            );
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Buscar producto',
            hintText: 'SKU, código de barras o nombre del producto',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() {
            _productQuery = value;
            _productToAdd = null;
          }),
          onSubmitted: (_) {
            if (_hasExactProductCode(data, controller.text)) {
              _addFirstMatchingProduct(
                data,
                exactOnly: true,
                keepSearchFocus: true,
              );
            } else {
              onSubmitted();
            }
          },
        ),
      );
    },
    optionsViewBuilder: (context, onSelected, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        child: SizedBox(
          width: compact ? 420 : 560,
          child: options.isEmpty
              ? ListTile(
                  title: Text(
                    _needsWarehouse && _warehouse == null
                        ? 'Seleccione una bodega para buscar.'
                        : _needsWarehouse
                        ? 'No hay stock vendible en el origen seleccionado.'
                        : 'No hay coincidencias disponibles.',
                  ),
                )
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
                      leading: _productThumbnail(product.imageUrl, 40),
                      title: Text('${product.sku} · ${product.name}'),
                      subtitle: Text(
                        [
                          if (product.description.trim().isNotEmpty)
                            product.description.trim(),
                          'Unitario ${_money(product.unitPriceInCents / 100, data.currency)}',
                          if (product.packagePriceInCents != null)
                            'Paquete ${_money(product.packagePriceInCents! / 100, data.currency)}',
                          'Venta: ${product.packagingPresentationName ?? 'Unidad'} · ${product.unitsPerPresentation} unidades',
                          'Stock en origen: ${_stockLabel(product, data)}',
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelected(product),
                    );
                  },
                ),
        ),
      ),
    ),
  );

  List<DocumentLinesGridColumn> _lineColumns(_FormData data) => [
    const DocumentLinesGridColumn(label: '#', width: 34),
    const DocumentLinesGridColumn(label: 'SKU', width: 78),
    const DocumentLinesGridColumn(label: 'DESCRIPCIÓN', width: 190),
    const DocumentLinesGridColumn(label: 'CANTIDAD', width: 132),
    if (widget.kind == SalesDocumentKind.returnItem)
      const DocumentLinesGridColumn(label: 'DAÑADAS', width: 140),
    const DocumentLinesGridColumn(label: 'PRECIO UNIT.', width: 105),
    if (_supportsDiscount)
      const DocumentLinesGridColumn(label: '% DESC.', width: 76),
    const DocumentLinesGridColumn(label: 'IVA', width: 48),
    const DocumentLinesGridColumn(label: 'TOTAL', width: 104),
    const DocumentLinesGridColumn(label: '', width: 44),
  ];

  Widget _productThumbnail(String? url, double size) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox.square(
        dimension: size,
        child: url == null || url.trim().isEmpty
            ? ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: colors.onSurfaceVariant,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _lineCells(
    _DraftLine line,
    int index,
    _FormData data, {
    required VoidCallback select,
  }) {
    final theme = Theme.of(context);
    final isReturn = widget.kind == SalesDocumentKind.returnItem;
    final quantity = int.tryParse(line.quantity.text) ?? 0;
    final quantityStep = isReturn ? 1 : line.quantityStep;
    final minimum = isReturn ? 1 : _lineMinimumQuantity(line);
    final numericStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final validation = _validateLine(line, data);
    final description = <Widget>[
      Text(
        line.product.name.toUpperCase(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (line.product.description.trim().isNotEmpty)
        Text(
          line.product.description.trim(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      if (widget.kind == SalesDocumentKind.invoice &&
          line.product.promotionalPriceInCents == null)
        Text(
          'Sin promocion aprobada · descuento no permitido',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      if (isReturn)
        Text(
          'Buenas: ${quantity - (int.tryParse(line.damagedQuantity.text) ?? 0)} · Pendientes antes: ${line.maxQuantity}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      if (line.product.promotionalPriceInCents != null)
        Text(
          'Promoción · máximo ${_percent(_maximumLineDiscount(line.product))}% descuento',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
      if (!isReturn)
        Text(
          _stockLabel(line.product, data),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      if (validation != null)
        Text(
          validation,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
    ];
    return [
      Center(child: Text('${index + 1}', style: numericStyle)),
      Text(
        line.product.sku,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: numericStyle?.copyWith(fontWeight: FontWeight.w600),
      ),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: select,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: description,
        ),
      ),
      Row(
        children: [
          IconButton(
            tooltip: 'Restar $quantityStep unidades',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 26, height: 32),
            onPressed: quantity - quantityStep < minimum
                ? null
                : () => setState(() {
                    line.quantity.text = '${quantity - quantityStep}';
                    _markDirty();
                  }),
            icon: const Icon(Icons.remove, size: 18),
          ),
          Expanded(
            child: TextField(
              controller: line.quantity,
              focusNode: widget.kind == SalesDocumentKind.quote
                  ? _quantityFocus.putIfAbsent(line.product.id, FocusNode.new)
                  : null,
              textAlign: TextAlign.center,
              style: numericStyle,
              decoration: InputDecoration(
                labelText: line.maxQuantity == null
                    ? 'Cantidad'
                    : 'Máx. ${line.maxQuantity}',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              readOnly: false,
              onChanged: (_) => setState(_markDirty),
            ),
          ),
          IconButton(
            tooltip: 'Sumar $quantityStep unidades',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 26, height: 32),
            onPressed: () => setState(() {
              line.quantity.text = '${quantity + quantityStep}';
              _markDirty();
            }),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
      if (isReturn)
        Row(
          children: [
            IconButton(
              tooltip: 'Restar una unidad dañada',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 18, height: 28),
              onPressed: (int.tryParse(line.damagedQuantity.text) ?? 0) == 0
                  ? null
                  : () => setState(() {
                      line.damagedQuantity.text =
                          '${int.parse(line.damagedQuantity.text) - 1}';
                      _markDirty();
                    }),
              icon: const Icon(Icons.remove, size: 14),
            ),
            Expanded(
              child: TextField(
                controller: line.damagedQuantity,
                textAlign: TextAlign.center,
                style: numericStyle,
                decoration: const InputDecoration(
                  labelText: 'Dañadas',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 6,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(_markDirty),
              ),
            ),
            IconButton(
              tooltip: 'Sumar una unidad dañada',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 18, height: 28),
              onPressed:
                  (int.tryParse(line.damagedQuantity.text) ?? 0) >= quantity
                  ? null
                  : () => setState(() {
                      line.damagedQuantity.text =
                          '${int.parse(line.damagedQuantity.text) + 1}';
                      _markDirty();
                    }),
              icon: const Icon(Icons.add, size: 14),
            ),
          ],
        ),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          _money(
            double.tryParse(line.price.text.replaceAll(',', '.')) ?? 0,
            data.currency,
          ),
          textAlign: TextAlign.end,
          style: numericStyle,
        ),
      ),
      if (_supportsDiscount)
        TextField(
          controller: line.discount,
          textAlign: TextAlign.end,
          style: numericStyle,
          decoration: const InputDecoration(
            labelText: 'Descuento %',
            suffixText: '%',
            isDense: true,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          onChanged: (value) => _onLineDiscountChanged(line, value),
        ),
      Tooltip(
        message: 'Tasa fiscal configurada. No se agrega al total hasta que el contrato comercial persista el desglose de IVA.',
        child: Text(
          '${data.taxPercentage}%${data.pricesIncludeTax ? ' incl.' : ''}',
          style: numericStyle,
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          _money(_lineTotal(line), data.currency),
          textAlign: TextAlign.end,
          style: numericStyle?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      IconButton(
        tooltip: 'Eliminar ${line.product.name}',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        onPressed: () => setState(() {
          _lines.removeAt(index).dispose();
          _markDirty();
        }),
        icon: const Icon(Icons.delete_outline),
      ),
    ];
  }

  int _lineMinimumQuantity(_DraftLine line) {
    final step = line.quantityStep < 1 ? 1 : line.quantityStep;
    final minimum = line.product.minimumSaleQuantity < step
        ? step
        : line.product.minimumSaleQuantity;
    return ((minimum + step - 1) ~/ step) * step;
  }

  Widget _lineEditor(
    _DraftLine line,
    int index,
    String currency,
    _FormData data,
  ) {
    final theme = Theme.of(context);
    final isQuote = widget.kind == SalesDocumentKind.quote;
    final isReturn = widget.kind == SalesDocumentKind.returnItem;
    final currentStock = _needsWarehouse
        ? _availableStock(data, line.product)
        : line.product.currentStock;
    final stockIcon = currentStock <= 0
        ? Icons.remove_shopping_cart_outlined
        : currentStock <= line.product.reorderPoint
        ? Icons.warning_amber_outlined
        : Icons.inventory_2_outlined;
    final validationIssue = _validateLine(line, data);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.product.name,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (line.product.sku.trim().isNotEmpty)
                            Text('SKU ${line.product.sku}'),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (line
                                      .product
                                      .packagingPresentationName
                                      ?.isNotEmpty ==
                                  true)
                                Text(
                                  'Venta: ${line.product.packagingPresentationName} · mínimo ${line.product.minimumSaleQuantity}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              if (!isReturn)
                                Semantics(
                                  label:
                                      'Inventario: ${_stockLabel(line.product, data)}',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(stockIcon, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        _stockLabel(line.product, data),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              if (isQuote &&
                                  line.product.promotionalPriceInCents != null)
                                Text(
                                  'Promoción ${_money(line.product.promotionalPriceInCents! / 100, currency)} · descuento máx. ${_percent(_maximumLineDiscount(line.product))}%',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.tertiary,
                                  ),
                                ),
                              if (line.product.packagePriceInCents != null)
                                Text(
                                  'Precio por paquete ${_money(line.product.packagePriceInCents! / 100, currency)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Importe de línea',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          _money(_lineTotal(line), currency),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
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
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 190,
                  child: Row(
                    children: [
                      if (isQuote)
                        IconButton(
                          tooltip: 'Restar ${line.quantityStep}',
                          onPressed: () {
                            final current =
                                int.tryParse(line.quantity.text) ??
                                line.quantityStep;
                            final next = current - line.quantityStep;
                            if (next < line.quantityStep) return;
                            setState(() => line.quantity.text = '$next');
                            _markDirty();
                          },
                          icon: const Icon(Icons.remove),
                        ),
                      Expanded(
                        child: TextField(
                          controller: line.quantity,
                          focusNode: isQuote
                              ? _quantityFocus.putIfAbsent(
                                  line.product.id,
                                  FocusNode.new,
                                )
                              : null,
                          decoration: InputDecoration(
                            labelText: line.maxQuantity == null
                                ? 'Cantidad'
                                : 'Cantidad disponible ${line.maxQuantity}',
                            helperText:
                                isQuote &&
                                    line.product.packagingPresentationName !=
                                        null
                                ? '${line.product.packagingPresentationName}: +${line.quantityStep} por presentación'
                                : null,
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          readOnly: isReturn,
                          onChanged: (_) => setState(_markDirty),
                          onSubmitted: isQuote
                              ? (_) => _productSearchFocus?.requestFocus()
                              : null,
                        ),
                      ),
                      if (isQuote)
                        IconButton(
                          tooltip: 'Sumar ${line.quantityStep}',
                          onPressed: () {
                            final current =
                                int.tryParse(line.quantity.text) ?? 0;
                            setState(
                              () => line.quantity.text =
                                  '${current + line.quantityStep}',
                            );
                            _markDirty();
                          },
                          icon: const Icon(Icons.add),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Precio unitario: ${_money(double.tryParse(line.price.text.replaceAll(',', '.')) ?? 0, currency)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                if (_supportsDiscount)
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: line.discount,
                      decoration: const InputDecoration(
                        labelText: 'Descuento %',
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onChanged: (value) => _onLineDiscountChanged(line, value),
                    ),
                  ),
                if (isReturn)
                  SizedBox(
                    width: 190,
                    child: TextField(
                      controller: line.damagedQuantity,
                      decoration: InputDecoration(
                        labelText: 'Unidades dañadas',
                        helperText:
                            'Buenas: ${(int.tryParse(line.quantity.text) ?? 0) - (int.tryParse(line.damagedQuantity.text) ?? 0)} · Buenas vuelven a origen, dañadas a cuarentena',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(_markDirty),
                    ),
                  ),
              ],
            ),
            if (validationIssue != null) ...[
              const SizedBox(height: 8),
              Text(
                validationIssue,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summary(_FormData data) {
    final currency = widget.kind == SalesDocumentKind.returnItem
        ? _invoice?.currencyCode ?? data.currency
        : data.currency;
    final units = _lines.fold<int>(
      0,
      (sum, line) => sum + (int.tryParse(line.quantity.text) ?? 0),
    );
    final title = switch (widget.kind) {
      SalesDocumentKind.quote => 'Resumen de cotización',
      SalesDocumentKind.order => 'Resumen del pedido',
      SalesDocumentKind.invoice => 'Resumen de factura',
      SalesDocumentKind.returnItem => 'Resumen de devolución',
      SalesDocumentKind.consignment => 'Resumen de consignación',
    };
    final customer = widget.kind == SalesDocumentKind.returnItem
        ? _invoice?.customerName
        : _customer?.displayName ?? _customer?.name;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    widget.kind == SalesDocumentKind.returnItem
                        ? Icons.calculate_outlined
                        : Icons.receipt_long_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _sectionTitle(title)),
                ],
              ),
              const SizedBox(height: 16),
              _summaryRow('Cliente', customer ?? 'Sin seleccionar'),
              if (widget.kind == SalesDocumentKind.returnItem &&
                  _invoice != null)
                _summaryRow('Factura', _invoice!.invoiceNumber),
              if (widget.kind != SalesDocumentKind.returnItem)
                _summaryRow('Moneda', currency),
              if (_agent != null) _summaryRow('Agente', _agent!.name),
              if (_quote != null)
                _summaryRow('Cotización de origen', _quote!.quoteNumber),
              if (_warehouse != null)
                _summaryRow('Bodega de salida', _warehouse!.name),
              if (widget.kind == SalesDocumentKind.quote && _validUntil != null)
                _summaryRow('Vigencia', _formatDate(_validUntil!)),
              const Divider(height: 24),
              _summaryRow('Líneas', '${_lines.length}'),
              _summaryRow('Unidades', '$units'),
              if (widget.kind == SalesDocumentKind.quote) ...[
                _summaryRow(
                  'Descuento general solicitado',
                  '${_generalDiscount.text}%',
                ),
                _summaryRow('Subtotal', _money(_subtotal, currency)),
                _summaryRow('Descuentos', _money(_discountTotal, currency)),
                _summaryRow('Estado al guardar', 'Borrador'),
              ] else if (widget.kind != SalesDocumentKind.returnItem) ...[
                _summaryRow('Subtotal', _money(_subtotal, currency)),
              ],
              if (widget.kind == SalesDocumentKind.returnItem) ...[
                if (_returnPreview == null)
                  const LinearProgressIndicator()
                else ...[
                  _summaryRow(
                    'Saldo pendiente',
                    _money(_returnPreview!.outstandingAmount, currency),
                  ),
                  _summaryRow(
                    'Reducción de deuda',
                    _money(
                      _total < _returnPreview!.outstandingAmount
                          ? _total
                          : _returnPreview!.outstandingAmount,
                      currency,
                    ),
                  ),
                  _summaryRow(
                    'Excedente',
                    _money(
                      (_total - _returnPreview!.outstandingAmount).clamp(
                        0,
                        double.infinity,
                      ),
                      currency,
                    ),
                  ),
                  if (_total > _returnPreview!.outstandingAmount) ...[
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
                    const SizedBox(height: 8),
                    Text(
                      _returnResolution == ReturnFinancialResolution.refund
                          ? 'El reembolso se valida contra los pagos confirmados.'
                          : 'El crédito se registra solo sobre dinero recibido.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ],
              const Divider(height: 28),
              Text('Total', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                _money(_total, currency),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (widget.kind == SalesDocumentKind.returnItem)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'El RPC valida las cantidades devueltas contra la factura.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

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
        Expanded(
          flex: 2,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: Text(value, textAlign: TextAlign.end)),
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
  }) : quantity = TextEditingController(
         text: '${quantity ?? _initialUnits(product)}',
       ),
       price = TextEditingController(
         text: (price ?? salePrice)?.toStringAsFixed(2) ?? '',
       ),
       discount = TextEditingController(text: '${initialDiscount ?? 0}'),
       damagedQuantity = TextEditingController(text: '0') {
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
  final TextEditingController damagedQuantity;
  final TextEditingController conditionNote = TextEditingController();
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
    damagedQuantity.dispose();
    conditionNote.dispose();
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
    required this.taxPercentage,
    required this.pricesIncludeTax,
    required this.agents,
    required this.warehouses,
    this.inventoryBalances = const [],
    required this.quotes,
    required this.invoices,
    this.returns = const [],
    this.editingQuote,
  });

  final List<CustomerDto> customers;
  final List<ProductSummaryDto> products;
  final String currency;
  final String taxPercentage;
  final bool pricesIncludeTax;
  final List<SalesAgentDto> agents;
  final List<WarehouseDto> warehouses;
  final List<InventoryBalanceDto> inventoryBalances;
  final List<SalesQuoteDto> quotes;
  final List<SalesInvoiceDto> invoices;
  final List<SalesReturnDto> returns;
  final SalesQuoteDto? editingQuote;
}
