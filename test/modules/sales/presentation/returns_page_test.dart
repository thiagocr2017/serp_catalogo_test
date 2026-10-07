import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/sales/api/return_api.dart';
import 'package:serp/modules/sales/presentation/pages/returns_page.dart';

void main() {
  testWidgets('devolucion no desborda en ListTile denso', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [returnApiProvider.overrideWithValue(_ReturnApi())],
        child: MaterialApp(
          theme: ThemeData(listTileTheme: const ListTileThemeData(dense: true)),
          home: const ReturnsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DEV-001'), findsOneWidget);
    expect(find.text('CRC 12.00'), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ReturnApi implements ReturnApi {
  @override
  Future<List<SalesReturnDto>> getReturns() async => const [
    SalesReturnDto(
      id: 'return-1',
      returnNumber: 'DEV-001',
      customerName: 'Cliente Demo',
      status: ReturnStatus.confirmed,
      totalAmount: 12,
      currencyCode: 'CRC',
      reason: 'Producto defectuoso',
    ),
  ];

  @override
  Future<SalesReturnDto?> getReturnById(String id) async => null;

  @override
  Future<SalesReturnPreviewDto> previewReturn(String invoiceId) =>
      throw UnimplementedError();

  @override
  Future<SalesReturnDto> confirmReturn(ConfirmSalesReturnCommand command) =>
      throw UnimplementedError();

  @override
  Future<SalesReturnDto> createReturn({
    required String invoiceId,
    required String customerId,
    required String customerName,
    required String reason,
    required List<ReturnLineInput> lines,
  }) async => throw UnimplementedError();
}
