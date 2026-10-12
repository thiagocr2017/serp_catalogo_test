import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/shared/theme/app_theme.dart';
import 'package:serp/shared/widgets/document_lines_grid.dart';

void main() {
  test('subtotal aplica descuento porcentual sin alterar la tasa fiscal', () {
    expect(
      calculateDocumentLineSubtotal(
        quantity: 4,
        unitPrice: 12.5,
        discountPercent: 10,
      ),
      45,
    );
    expect(calculateDocumentLineSubtotal(quantity: 2, unitPrice: 3.25), 6.5);
  });

  testWidgets('Insert inicia la línea y el stepper de cantidad funciona', (
    tester,
  ) async {
    var rows = 1;
    var quantity = 1;
    final searchFocus = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: DocumentLinesGrid(
                searchField: TextField(
                  focusNode: searchFocus,
                  decoration: const InputDecoration(),
                ),
                focusSearch: searchFocus.requestFocus,
                columns: const [
                  DocumentLinesGridColumn(label: '#', width: 40),
                  DocumentLinesGridColumn(label: 'PRODUCTO', width: 220),
                  DocumentLinesGridColumn(label: 'CANTIDAD', width: 180),
                  DocumentLinesGridColumn(label: 'ACCIONES', width: 60),
                ],
                rowCount: rows,
                rowBuilder: (index, selected, select) => [
                  Text('${index + 1}'),
                  Text('Producto con descripción extensa'),
                  Row(
                    children: [
                      IconButton(
                        onPressed: quantity <= 1
                            ? null
                            : () => setState(() => quantity--),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$quantity'),
                      IconButton(
                        onPressed: () => setState(() => quantity++),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
                onAddLine: () => setState(() => rows++),
                onRemoveLine: (_) => setState(() => rows--),
                emptyState: const Text('Vacío'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField).first);
    await tester.sendKeyEvent(LogicalKeyboardKey.insert);
    await tester.pumpAndSettle();
    expect(find.text('Producto con descripción extensa'), findsNWidgets(2));
    await tester.tap(find.widgetWithIcon(IconButton, Icons.add).last);
    await tester.pump();
    expect(find.text('2'), findsWidgets);
    expect(tester.takeException(), isNull);
    searchFocus.dispose();
  });

  testWidgets('F2 enfoca búsqueda, Insert agrega y Delete quita fila activa', (
    tester,
  ) async {
    final rowIds = <int>[0];
    var nextId = 1;
    final searchFocus = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DocumentLinesGrid(
              searchField: TextField(focusNode: searchFocus),
              focusSearch: searchFocus.requestFocus,
              columns: const [
                DocumentLinesGridColumn(label: 'SKU', width: 120),
                DocumentLinesGridColumn(label: 'ACCIONES', width: 60),
              ],
              rowCount: rowIds.length,
              rowBuilder: (index, selected, select) => [
                GestureDetector(
                  onTap: select,
                  child: Text('SKU-${rowIds[index]}'),
                ),
                const SizedBox.shrink(),
              ],
              onAddLine: () => setState(() => rowIds.add(nextId++)),
              onRemoveLine: (index) => setState(() => rowIds.removeAt(index)),
              emptyState: const Text('Vacío'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    expect(searchFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.insert);
    await tester.pumpAndSettle();
    expect(find.text('SKU-1'), findsOneWidget);
    expect(find.text('Agregar línea (Ins)'), findsNothing);

    await tester.tap(find.text('SKU-0'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text('SKU-0'), findsNothing);
    expect(find.text('SKU-1'), findsOneWidget);
    searchFocus.dispose();
  });

  testWidgets('Backspace dentro de un editor no elimina la fila', (
    tester,
  ) async {
    var rows = 1;
    final controller = TextEditingController(text: '12');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => DocumentLinesGrid(
              searchField: const SizedBox.shrink(),
              focusSearch: () {},
              columns: const [
                DocumentLinesGridColumn(label: 'CANTIDAD', width: 100),
              ],
              rowCount: rows,
              rowBuilder: (index, selected, select) => [
                TextField(controller: controller),
              ],
              onAddLine: () {},
              onRemoveLine: (_) => setState(() => rows--),
              emptyState: const Text('Vacío'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Vacío'), findsNothing);
  });

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets('tabla conserva layout en tema ${theme.brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(700, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DocumentLinesGrid(
                searchField: const TextField(),
                focusSearch: focus.requestFocus,
                columns: const [
                  DocumentLinesGridColumn(label: 'SKU', width: 130),
                  DocumentLinesGridColumn(label: 'DESCRIPCIÓN', width: 280),
                  DocumentLinesGridColumn(label: 'SUBTOTAL', width: 140),
                ],
                rowCount: 1,
                rowBuilder: (index, selected, select) => const [
                  Text('SKU-0001'),
                  Text('Descripción larga con contenido que debe poder leerse'),
                  Text('123456.78'),
                ],
                onAddLine: () {},
                onRemoveLine: (_) {},
                emptyState: const Text('Vacío'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
