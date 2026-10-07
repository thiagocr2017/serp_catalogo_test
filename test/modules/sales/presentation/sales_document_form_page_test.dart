import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/configuration/api/configuration_api.dart';
import 'package:serp/modules/inventory/api/inventory_api.dart';
import 'package:serp/modules/product/api/product_api.dart';
import 'package:serp/modules/sales/api/customer_api.dart';
import 'package:serp/modules/sales/api/consignment_api.dart';
import 'package:serp/modules/sales/api/order_api.dart';
import 'package:serp/modules/sales/api/quote_api.dart';
import 'package:serp/modules/sales/api/return_api.dart';
import 'package:serp/modules/sales/api/sales_api.dart';
import 'package:serp/modules/sales/api/sales_invoice_api.dart';
import 'package:serp/modules/sales/api/sales_routes.dart';
import 'package:serp/modules/sales/presentation/pages/sales_document_form_page.dart';

void main() {
  testWidgets('lista abre detalle y regresa al índice', (tester) async {
    final quote = SalesQuoteDto(
      id: 'quote-1',
      quoteNumber: 'COT-000001',
      customerId: 'customer-1',
      customerName: 'Tienda Demo',
      status: QuoteStatus.draft,
      totalAmount: 25,
      currencyCode: 'CRC',
      lines: const [
        SalesQuoteLineDto(
          id: 'line-1',
          quoteId: 'quote-1',
          productId: 'product-1',
          quantity: 2,
          unitPrice: 12.5,
          totalPrice: 25,
          productSku: 'SKU-1',
          productName: 'Producto Demo',
        ),
      ],
    );
    final api = _QuoteApi(quotes: [quote]);
    await tester.pumpWidget(_app(api, initialLocation: '/sales/quotes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('COT-000001'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de cotización'), findsOneWidget);
    expect(find.textContaining('Producto Demo'), findsOneWidget);
    expect(find.textContaining('Borrador'), findsOneWidget);
    await tester.tap(find.text('Ver perfil del cliente'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil de cliente'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a cotización'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de cotización'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver a cotizaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Cotizaciones'), findsOneWidget);
    expect(find.text('COT-000001'), findsOneWidget);
  });

  testWidgets('confirma devolucion desde factura y navega al detalle', (
    tester,
  ) async {
    final invoice = SalesInvoiceDto(
      id: 'invoice-1',
      invoiceNumber: 'FAC-0001',
      customerName: 'Tienda Demo',
      customerId: 'customer-1',
      status: SalesInvoiceStatus.confirmed,
      totalAmount: 25,
      currencyCode: 'CRC',
      lines: const [
        SalesInvoiceLineDto(
          id: 'invoice-line-1',
          invoiceId: 'invoice-1',
          productId: 'product-1',
          productSku: 'SKU-1',
          productName: 'Producto Demo',
          quantity: 2,
          unitPrice: 12.5,
          totalPrice: 25,
        ),
      ],
    );
    final returnApi = _ReturnApi()
      ..preview = const SalesReturnPreviewDto(
        invoiceId: 'invoice-1',
        customerId: 'customer-1',
        customerName: 'Tienda Demo',
        currencyCode: 'CRC',
        totalAmount: 25,
        paidAmount: 0,
        outstandingAmount: 25,
        availableQuantities: {'invoice-line-1': 2},
        sellableLocations: [
          ReturnLocationDto(
            id: 'location-sellable',
            warehouseId: 'warehouse-1',
            code: 'VENTA',
            name: 'Vendible',
          ),
        ],
        quarantineLocations: [],
      );
    await tester.pumpWidget(
      _app(
        _QuoteApi(),
        initialLocation: '/sales/returns/new?invoiceId=invoice-1&returnTo=%2Fsales%2Finvoices',
        invoiceApi: _SalesInvoiceApi([invoice]),
        returnApi: returnApi,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo de devolución *'),
      'Empaque abierto',
    );
    await tester.tap(find.text('Producto Demo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar devolución'));
    await tester.tap(find.text('Confirmar devolución'));
    await tester.pumpAndSettle();

    expect(returnApi.command, isNotNull);
    expect(returnApi.command!.invoiceId, 'invoice-1');
    expect(returnApi.command!.lines.single.invoiceLineId, 'invoice-line-1');
    expect(returnApi.command!.lines.single.locationId, 'location-sellable');
    expect(find.text('Detalle de devolución'), findsOneWidget);
  });

  for (final entry in [
    (SalesDocumentKind.order, '/sales/orders/new', 'Nuevo pedido'),
    (
      SalesDocumentKind.invoice,
      '/sales/invoices/new',
      'Nueva factura de venta',
    ),
    (SalesDocumentKind.returnItem, '/sales/returns/new', 'Nueva devolución'),
    (
      SalesDocumentKind.consignment,
      '/sales/consignments/new',
      'Nueva consignación',
    ),
  ]) {
    testWidgets('${entry.$3} muestra su formulario operativo', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app(_QuoteApi(), initialLocation: entry.$2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(entry.$3), findsOneWidget);
      if (entry.$1 != SalesDocumentKind.returnItem) {
        expect(
          find.text(
            entry.$1 == SalesDocumentKind.quote
                ? 'Guardar borrador'
                : 'Guardar documento',
          ),
          findsOneWidget,
        );
      }
      if (entry.$1 == SalesDocumentKind.invoice) {
        expect(find.text('Bodega de salida *'), findsOneWidget);
        expect(find.text('Ubicación de salida *'), findsNothing);
      }
      if (entry.$1 == SalesDocumentKind.order ||
          entry.$1 == SalesDocumentKind.consignment) {
        expect(find.text('Ubicación de salida *'), findsOneWidget);
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  }

  testWidgets('cotizacion valida se crea y formulario vacio no persiste', (
    tester,
  ) async {
    final quoteApi = _QuoteApi();
    await tester.pumpWidget(_app(quoteApi));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar cliente *'),
      'Tienda',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tienda Demo').last);
    await tester.pumpAndSettle();

    expect(find.text('Tipo de cambio *'), findsNothing);
    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();
    expect(quoteApi.createCount, 0);
    expect(find.text('Agregue al menos un producto.'), findsOneWidget);
    expect(find.byType(SalesDocumentFormPage), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar producto'),
      'SKU-1',
    );
    await tester.pumpAndSettle();
    await _tapAction(tester, find.widgetWithIcon(IconButton, Icons.add).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();

    expect(quoteApi.createCount, 1);
    expect(quoteApi.lastCustomerId, 'customer-1');
    expect(quoteApi.lastLines.single.productId, 'product-1');
    expect(quoteApi.lastLines.single.quantity, 2);
    expect(quoteApi.lastLines.single.unitPrice, 12.5);
    expect(quoteApi.lastExchangeRate, 1.0);
    expect(find.byType(SalesDocumentFormPage), findsNothing);
  });

  testWidgets('busca producto por descripcion y duplicado suma cantidad', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_QuoteApi()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Moneda: CRC'), findsOneWidget);
    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Buscar producto'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar producto'),
      'utensilios',
    );
    await tester.pumpAndSettle();
    expect(find.text('SKU-1 · Producto Demo'), findsOneWidget);
    await _tapAction(tester, find.widgetWithIcon(IconButton, Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.text('Cantidad'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar producto'),
      '',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar producto'),
      'SKU-1',
    );
    await tester.pumpAndSettle();
    await _tapAction(tester, find.widgetWithIcon(IconButton, Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Cantidad'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Cantidad'))
          .controller!
          .text,
      '3',
    );
  });

  testWidgets('muestra precio y forma de venta publicados por Productos', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_QuoteApi()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Buscar producto'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar producto'),
      'SKU-1',
    );
    await tester.pumpAndSettle();
    await _tapAction(tester, find.widgetWithIcon(IconButton, Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.text('Venta: Caja · Mín. 2'), findsOneWidget);
    expect(find.text('Cantidad'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Cantidad'))
          .controller!
          .text,
      '2',
    );
    final lineCard = find
        .ancestor(
          of: find.text('Venta: Caja · Mín. 2'),
          matching: find.byType(Card),
        )
        .first;
    final priceField = tester.widget<TextField>(
      find.descendant(of: lineCard, matching: find.byType(TextField)).at(1),
    );
    expect(priceField.controller!.text, '12.50');
  });

  testWidgets('cantidad inicial e incremento respetan caja de seis unidades', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_QuoteApi(), productApi: const _ProductApi(unitsPerPresentation: 6)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar producto'),
      'SKU-1',
    );
    await tester.pumpAndSettle();
    await _tapAction(tester, find.widgetWithIcon(IconButton, Icons.add).first);
    await tester.pumpAndSettle();
    final quantity = find.widgetWithText(TextField, 'Cantidad');
    expect(tester.widget<TextField>(quantity).controller!.text, '6');
    expect(find.text('Caja: 6 unidades por incremento'), findsOneWidget);
    await _tapAction(tester, find.widgetWithIcon(IconButton, Icons.add).last);
    expect(tester.widget<TextField>(quantity).controller!.text, '12');
  });

  testWidgets('edita borrador y vuelve al detalle con cambios guardados', (
    tester,
  ) async {
    final quote = SalesQuoteDto(
      id: 'quote-edit',
      quoteNumber: 'COT-EDIT',
      customerId: 'customer-1',
      customerName: 'Tienda Demo',
      status: QuoteStatus.draft,
      totalAmount: 25,
      currencyCode: 'CRC',
      lines: const [
        SalesQuoteLineDto(
          id: 'line-edit',
          quoteId: 'quote-edit',
          productId: 'product-1',
          quantity: 2,
          unitPrice: 12.5,
          totalPrice: 25,
          productSku: 'SKU-1',
          productName: 'Producto Demo',
          presentationName: 'Caja',
        ),
      ],
    );
    final api = _QuoteApi(quotes: [quote]);
    await tester.pumpWidget(
      _app(
        api,
        initialLocation: '/sales/quotes/quote-edit/edit?returnTo=%2Fsales%2Fquotes%2Fquote-edit',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Editar cotización'), findsOneWidget);
    expect(find.textContaining('Producto Demo'), findsOneWidget);
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(api.updateCount, 1);
    expect(find.text('Detalle de cotización'), findsOneWidget);
  });

  testWidgets('valida la línea en sitio y conserva sin persistir', (
    tester,
  ) async {
    final quoteApi = _QuoteApi();
    await tester.pumpWidget(_app(quoteApi));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar cliente *'),
      'Tienda',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tienda Demo').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar producto'),
      'SKU-1',
    );
    await tester.pumpAndSettle();
    await _tapAction(tester, find.widgetWithIcon(IconButton, Icons.add).first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Precio unitario'),
      '0',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar borrador'));
    await tester.pumpAndSettle();

    expect(quoteApi.createCount, 0);
    expect(
      find.text('El precio unitario debe ser mayor que cero.'),
      findsAtLeastNWidgets(1),
    );
    expect(find.byType(SalesDocumentFormPage), findsOneWidget);
  });

  testWidgets('promocion es el maximo y descuento menor la reemplaza', (
    tester,
  ) async {
    final quoteApi = _QuoteApi();
    await tester.pumpWidget(
      _app(quoteApi, productApi: const _ProductApi(promoPrice: 1000)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar cliente *'),
      'Tienda',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tienda Demo').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Buscar producto'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar producto'),
      'SKU-1',
    );
    await tester.pumpAndSettle();
    await _tapAction(tester, find.widgetWithIcon(IconButton, Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.text('Promoción · CRC 10.00'), findsOneWidget);
    expect(find.text('Máximo 20% vs. precio normal'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Precio unitario'))
          .controller!
          .text,
      '12.50',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Desc. %'))
          .controller!
          .text,
      '20.00',
    );

    await tester.enterText(find.widgetWithText(TextField, 'Desc. %'), '10');
    await tester.pumpAndSettle();
    expect(find.text('22.50'), findsWidgets);

    await tester.enterText(find.widgetWithText(TextField, 'Desc. %'), '25');
    await tester.pumpAndSettle();
    expect(find.textContaining('El descuento máximo'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Desc. %'))
          .controller!
          .text,
      '10',
    );
  });

  testWidgets('descuento general se limita a la promocion', (tester) async {
    await tester.pumpWidget(
      _app(_QuoteApi(), productApi: const _ProductApi(promoPrice: 1000)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar cliente *'),
      'Tienda',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tienda Demo').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Buscar producto'),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar producto'),
      'SKU-1',
    );
    await tester.pumpAndSettle();
    await _tapAction(tester, find.widgetWithIcon(IconButton, Icons.add).first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Descuento general %'),
      '30',
    );
    final generalField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Descuento general %'),
    );
    generalField.onSubmitted?.call(generalField.controller!.text);
    await tester.pumpAndSettle();

    expect(find.textContaining('se aplicó solo el máximo'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Desc. %'))
          .controller!
          .text,
      '20',
    );
    expect(find.text('20.00'), findsWidgets);
  });
}

Future<void> _tapAction(WidgetTester tester, Finder finder) async {
  final action = tester.widget<IconButton>(finder);
  expect(action.onPressed, isNotNull);
  action.onPressed!.call();
  await tester.pumpAndSettle();
}

Widget _app(
  _QuoteApi quoteApi, {
  String initialLocation = '/sales/quotes/new',
  _ProductApi? productApi,
  SalesInvoiceApi? invoiceApi,
  _ReturnApi? returnApi,
}) => ProviderScope(
  overrides: [
    customerApiProvider.overrideWithValue(_CustomerApi()),
    productApiProvider.overrideWithValue(productApi ?? const _ProductApi()),
    configurationApiProvider.overrideWithValue(_ConfigurationApi()),
    salesApiProvider.overrideWithValue(_SalesApi()),
    inventoryApiProvider.overrideWithValue(_InventoryApi()),
    quoteApiProvider.overrideWithValue(quoteApi),
    orderApiProvider.overrideWithValue(_OrderApi()),
    salesInvoiceApiProvider.overrideWithValue(invoiceApi ?? _SalesInvoiceApi()),
    returnApiProvider.overrideWithValue(returnApi ?? _ReturnApi()),
    consignmentApiProvider.overrideWithValue(_ConsignmentApi()),
  ],
  child: MaterialApp.router(
    routerConfig: GoRouter(
      initialLocation: initialLocation,
      routes: salesRoutes,
    ),
  ),
);

class _CustomerApi implements CustomerApi {
  final _customers = const [
    CustomerDto(
      id: 'customer-1',
      name: 'Tienda Demo',
      displayName: 'Tienda Demo',
      taxId: '123',
      phone: '8888-0000',
      email: 'tienda@example.test',
    ),
    CustomerDto(id: 'customer-inactive', name: 'Inactivo', isActive: false),
  ];

  @override
  Future<List<CustomerDto>> getCustomers() async => _customers;

  @override
  Future<CustomerDto?> getCustomerById(String id) async =>
      _customers.where((item) => item.id == id).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProductApi implements ProductApi {
  const _ProductApi({this.promoPrice, this.unitsPerPresentation = 1});

  final int? promoPrice;
  final int unitsPerPresentation;

  @override
  Future<List<ProductSummaryDto>> listProducts([
    ProductListQuery query = const ProductListQuery(),
  ]) async => [
    ProductSummaryDto(
      id: 'product-1',
      sku: 'SKU-1',
      name: 'Producto Demo',
      description: 'Set de utensilios de cocina',
      currentStock: 10,
      unitPriceInCents: 1250,
      promotionalPriceInCents: promoPrice,
      reorderPoint: 2,
      packagePriceInCents: 10000,
      packagingPresentationId: 'presentation-1',
      packagingPresentationName: 'Caja',
      unitsPerPresentation: unitsPerPresentation,
      minimumSaleQuantity: 2,
      minimumOrderQuantity: 10,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ConfigurationApi implements ConfigurationApi {
  @override
  Future<BusinessSettingsDto> getBusinessSettings() async =>
      const BusinessSettingsDto(
        defaultCurrency: 'CRC',
        decimalPlaces: 2,
        taxPercentage: '13',
        pricesIncludeTax: false,
        roundingMode: 'HALF_UP',
        roundingIncrement: '0.01',
        companyName: 'Empresa Demo',
        paymentMethods: '',
        version: 1,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SalesApi implements SalesApi {
  @override
  Future<List<SalesAgentDto>> getAgents(SalesAgentQuery query) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InventoryApi implements InventoryApi {
  @override
  Future<List<WarehouseDto>> getWarehouses({bool activeOnly = true}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuoteApi implements QuoteApi {
  _QuoteApi({this.quotes = const []});

  final List<SalesQuoteDto> quotes;
  int createCount = 0;
  int updateCount = 0;
  String? lastCustomerId;
  List<QuoteLineInput> lastLines = const [];
  double? lastExchangeRate;

  @override
  Future<List<SalesQuoteDto>> getQuotes() async => quotes;

  @override
  Future<SalesQuoteDto?> getQuoteById(String id) async =>
      quotes.where((quote) => quote.id == id).firstOrNull;

  @override
  Future<SalesQuoteDto> createQuote({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  }) async {
    createCount++;
    lastCustomerId = customerId;
    lastLines = lines;
    lastExchangeRate = exchangeRate;
    return SalesQuoteDto(
      id: 'quote-1',
      quoteNumber: 'COT-000001',
      customerId: customerId,
      customerName: customerName,
      status: QuoteStatus.draft,
      totalAmount: 12.5,
      currencyCode: currencyCode,
      lines: const [],
    );
  }

  @override
  Future<SalesQuoteDto> updateQuoteStatus(String id, QuoteStatus status) async {
    final quote = quotes.where((item) => item.id == id).first;
    final updated = SalesQuoteDto(
      id: quote.id,
      quoteNumber: quote.quoteNumber,
      customerName: quote.customerName,
      customerId: quote.customerId,
      status: status,
      totalAmount: quote.totalAmount,
      currencyCode: quote.currencyCode,
      lines: quote.lines,
    );
    quotes[quotes.indexOf(quote)] = updated;
    return updated;
  }

  @override
  Future<SalesQuoteDto> updateQuote({
    required String id,
    required String customerId,
    required String customerName,
    DateTime? validUntil,
    String? notes,
    String? agentId,
    required List<QuoteLineInput> lines,
  }) async {
    updateCount++;
    final quote = quotes.where((item) => item.id == id).first;
    final updated = SalesQuoteDto(
      id: quote.id,
      quoteNumber: quote.quoteNumber,
      customerName: customerName,
      customerId: customerId,
      status: quote.status,
      totalAmount: lines.fold(
        0,
        (sum, line) =>
            sum +
            line.quantity * line.unitPrice * (1 - line.discountPercent / 100),
      ),
      currencyCode: quote.currencyCode,
      validUntil: validUntil,
      notes: notes,
      agentId: agentId,
      lines: quote.lines,
    );
    lastLines = lines;
    quotes[quotes.indexOf(quote)] = updated;
    return updated;
  }
}

class _OrderApi implements OrderApi {
  @override
  Future<List<SalesOrderDto>> getOrders() async => const [];

  @override
  Future<SalesOrderDto?> getOrderById(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SalesInvoiceApi implements SalesInvoiceApi {
  _SalesInvoiceApi([this.invoices = const []]);

  final List<SalesInvoiceDto> invoices;

  @override
  Future<List<SalesInvoiceDto>> getInvoices() async => invoices;

  @override
  Future<SalesInvoiceDto?> getInvoiceById(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReturnApi implements ReturnApi {
  _ReturnApi();

  final List<SalesReturnDto> returns = const [];
  SalesReturnPreviewDto? preview;
  ConfirmSalesReturnCommand? command;

  @override
  Future<List<SalesReturnDto>> getReturns() async => returns;

  @override
  Future<SalesReturnDto?> getReturnById(String id) async => null;

  @override
  Future<SalesReturnPreviewDto> previewReturn(String invoiceId) =>
      Future.value(preview);

  @override
  Future<SalesReturnDto> confirmReturn(ConfirmSalesReturnCommand command) =>
      _confirm(command);

  Future<SalesReturnDto> _confirm(ConfirmSalesReturnCommand value) async {
    command = value;
    return SalesReturnDto(
      id: 'return-1',
      returnNumber: 'DEV-0001',
      customerName: 'Tienda Demo',
      customerId: 'customer-1',
      invoiceId: value.invoiceId,
      status: ReturnStatus.confirmed,
      totalAmount: 25,
      currencyCode: 'CRC',
      reason: value.reason,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ConsignmentApi implements ConsignmentApi {
  @override
  Future<List<SalesConsignmentDto>> getConsignments() async => const [];

  @override
  Future<SalesConsignmentDto?> getConsignmentById(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
