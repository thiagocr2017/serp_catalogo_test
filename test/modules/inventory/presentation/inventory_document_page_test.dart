import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:serp/modules/inventory/api/inventory_api.dart';
import 'package:serp/modules/inventory/api/inventory_routes.dart';
import 'package:serp/modules/inventory/presentation/pages/inventory_documents_page.dart';
import 'package:serp/shared/widgets/desktop_shell_widget.dart';

void main() {
  testWidgets('el borrador de traslado ofrece despacho transaccional único', (
    tester,
  ) async {
    final api = _FakeInventoryApi.withDraftTransfer();
    final router = GoRouter(
      initialLocation: '/inventory/documents',
      routes: [
        GoRoute(
          path: '/inventory/documents',
          builder: (_, _) => const InventoryDocumentsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [inventoryApiProvider.overrideWithValue(api)],
        child: MaterialApp.router(
          scaffoldMessengerKey: messengerKey,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Despachar traslado'), findsOneWidget);
    expect(find.text('Confirmar documento'), findsNothing);
    expect(find.text('Despachar'), findsNothing);
    await tester.tap(find.text('Despachar traslado'));
    await tester.pumpAndSettle();

    expect(api.dispatchCalls, 1);
    expect(api.confirmCalls, 0);
    expect(api.legacyDispatchCalls, 0);
    expect(find.text('Traslado despachado'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('DESPACHADA'), findsOneWidget);

    api.failNextTransit = true;
    await tester.tap(find.text('Marcar en tránsito'));
    await tester.pump();
    expect(api.transitCalls, 1);
    expect(messengerKey.currentState?.mounted, isTrue);
    expect(find.text('DESPACHADA'), findsOneWidget);

    await tester.tap(find.text('Marcar en tránsito'));
    await tester.pumpAndSettle();
    expect(api.transitCalls, 2);
    expect(find.text('EN_TRANSITO'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar recepción'));
    await tester.pumpAndSettle();
    expect(api.receiveCalls, 1);
    expect(find.text('RECIBIDA'), findsOneWidget);
  });

  testWidgets('detalle vuelve a la lista de documentos de inventario', (
    tester,
  ) async {
    final api = _FakeInventoryApi();
    final router = GoRouter(
      initialLocation: '/inventory/documents/document-1',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              DesktopShellWidget(currentLocation: state.uri.path, child: child),
          routes: inventoryRoutes,
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [inventoryApiProvider.overrideWithValue(api)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('INV-001'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a documentos'));
    await tester.pumpAndSettle();

    expect(find.text('Documentos de inventario'), findsOneWidget);
    expect(find.text('No hay documentos registrados.'), findsOneWidget);
  });
}

class _FakeInventoryApi implements InventoryApi {
  _FakeInventoryApi();

  _FakeInventoryApi.withDraftTransfer()
    : documents = [
        InventoryDocumentDto(
          id: 'transfer-1',
          number: 'TRA-001',
          type: InventoryDocumentType.transfer,
          status: 'BORRADOR',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ];

  List<InventoryDocumentDto> documents = const [];
  int confirmCalls = 0;
  int dispatchCalls = 0;
  int legacyDispatchCalls = 0;
  int transitCalls = 0;
  int receiveCalls = 0;
  bool failNextTransit = false;

  @override
  Future<InventoryDocumentDto?> getDocument(String id) async =>
      InventoryDocumentDto(
        id: 'document-1',
        number: 'INV-001',
        type: InventoryDocumentType.adjustment,
        status: 'CONFIRMED',
        createdAt: DateTime.utc(2026, 1, 1),
      );

  @override
  Future<List<InventoryDocumentDto>> getDocuments() async => documents;

  @override
  Future<InventoryDocumentDto> confirmDocument(String documentId) async {
    confirmCalls++;
    return _markDispatched();
  }

  InventoryDocumentDto _markDispatched() {
    final draft = documents.single;
    final dispatched = InventoryDocumentDto(
      id: draft.id,
      number: draft.number,
      type: draft.type,
      status: 'DESPACHADA',
      createdAt: draft.createdAt,
      lines: draft.lines,
    );
    documents = [dispatched];
    return dispatched;
  }

  @override
  Future<void> dispatchTransfer(String documentId) async {
    dispatchCalls++;
    _setStatus('DESPACHADA');
  }

  @override
  Future<void> markTransferInTransit(String documentId) async {
    transitCalls++;
    if (failNextTransit) {
      failNextTransit = false;
      throw StateError('fallo simulado');
    }
    _setStatus('EN_TRANSITO');
  }

  @override
  Future<void> receiveTransfer(String documentId) async {
    receiveCalls++;
    _setStatus('RECIBIDA');
  }

  @override
  Future<void> dispatchDocument(String documentId) async {
    legacyDispatchCalls++;
  }

  void _setStatus(String status) {
    final draft = documents.single;
    documents = [
      InventoryDocumentDto(
        id: draft.id,
        number: draft.number,
        type: draft.type,
        status: status,
        createdAt: draft.createdAt,
        lines: draft.lines,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
