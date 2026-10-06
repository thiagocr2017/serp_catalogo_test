import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/sales/api/consignment_api.dart';
import 'package:serp/modules/sales/api/return_api.dart';
import 'package:serp/modules/sales/presentation/pages/consignment_detail_page.dart';
import 'package:serp/modules/sales/presentation/pages/return_detail_page.dart';

void main() {
  testWidgets('detalle de devolucion vuelve al indice', (tester) async {
    final router = GoRouter(
      initialLocation: '/sales/returns/return-1',
      routes: [
        GoRoute(
          path: '/sales/returns',
          builder: (context, state) =>
              const Scaffold(body: Text('Lista devoluciones')),
        ),
        GoRoute(
          path: '/sales/returns/:id',
          builder: (context, state) => ReturnDetailPage(
            returnId: state.pathParameters['id']!,
            returnTo: state.uri.queryParameters['returnTo'],
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [returnApiProvider.overrideWithValue(_ReturnApi())],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('DEV-001'), findsOneWidget);
    expect(find.text('Producto devuelto'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a devoluciones'));
    await tester.pumpAndSettle();
    expect(find.text('Lista devoluciones'), findsOneWidget);
  });

  testWidgets('detalle de consignacion muestra saldo de lineas y vuelve', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/sales/consignments/consignment-1',
      routes: [
        GoRoute(
          path: '/sales/consignments',
          builder: (context, state) =>
              const Scaffold(body: Text('Lista consignaciones')),
        ),
        GoRoute(
          path: '/sales/consignments/:id',
          builder: (context, state) => ConsignmentDetailPage(
            consignmentId: state.pathParameters['id']!,
            returnTo: state.uri.queryParameters['returnTo'],
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consignmentApiProvider.overrideWithValue(_ConsignmentApi()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CON-001'), findsOneWidget);
    expect(find.textContaining('2 enviados'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a consignaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Lista consignaciones'), findsOneWidget);
  });
}

class _ReturnApi implements ReturnApi {
  @override
  Future<List<SalesReturnDto>> getReturns() async => [_return];

  @override
  Future<SalesReturnDto?> getReturnById(String id) async =>
      id == _return.id ? _return : null;

  @override
  Future<SalesReturnDto> createReturn({
    required String invoiceId,
    required String customerId,
    required String customerName,
    required String reason,
    required List<ReturnLineInput> lines,
  }) async => _return;
}

class _ConsignmentApi implements ConsignmentApi {
  @override
  Future<List<SalesConsignmentDto>> getConsignments() async => [_consignment];

  @override
  Future<SalesConsignmentDto?> getConsignmentById(String id) async =>
      id == _consignment.id ? _consignment : null;

  @override
  Future<SalesConsignmentDto> createConsignment({
    required String customerId,
    required String customerName,
    required String currencyCode,
    String? notes,
    String? agentId,
    required List<ConsignmentLineInput> lines,
    required String warehouseId,
    required String locationId,
  }) async => _consignment;

  @override
  Future<SalesConsignmentDto> registerReturn({
    required String consignmentId,
    required String productId,
    required int quantity,
  }) async => _consignment;
}

final _return = SalesReturnDto(
  id: 'return-1',
  returnNumber: 'DEV-001',
  customerName: 'Cliente Uno',
  customerId: 'customer-1',
  invoiceId: 'invoice-1',
  status: ReturnStatus.confirmed,
  totalAmount: 12,
  currencyCode: 'CRC',
  reason: 'Producto defectuoso',
  lines: const [
    SalesReturnLineDto(
      id: 'return-line-1',
      returnId: 'return-1',
      productId: 'product-1',
      invoiceLineId: 'invoice-line-1',
      productName: 'Producto devuelto',
      quantity: 1,
      unitPrice: 12,
      totalPrice: 12,
    ),
  ],
);

final _consignment = SalesConsignmentDto(
  id: 'consignment-1',
  consignmentNumber: 'CON-001',
  customerName: 'Cliente Dos',
  customerId: 'customer-2',
  status: ConsignmentStatus.partialReturn,
  totalAmount: 24,
  returnedAmount: 12,
  currencyCode: 'CRC',
  lines: const [
    SalesConsignmentLineDto(
      id: 'consignment-line-1',
      consignmentId: 'consignment-1',
      productId: 'product-2',
      productName: 'Vaso',
      quantity: 2,
      returnedQuantity: 1,
      unitPrice: 12,
      totalPrice: 24,
    ),
  ],
);
