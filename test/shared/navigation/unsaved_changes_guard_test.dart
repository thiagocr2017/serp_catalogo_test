import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/shared/navigation/unsaved_changes_guard.dart';

void main() {
  tearDown(() => UnsavedChangesGuard.instance.markClean());

  testWidgets('confirma antes de navegar con cambios sin guardar', (
    tester,
  ) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await UnsavedChangesGuard.instance.confirmNavigation(
                  context,
                );
              },
              child: const Text('Navegar'),
            ),
          ),
        ),
      ),
    );

    UnsavedChangesGuard.instance.markDirty();
    await tester.tap(find.text('Navegar'));
    await tester.pumpAndSettle();

    expect(find.text('Salir sin guardar'), findsOneWidget);

    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(UnsavedChangesGuard.instance.hasUnsavedChanges.value, isTrue);

    await tester.tap(find.text('Navegar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(UnsavedChangesGuard.instance.hasUnsavedChanges.value, isFalse);
  });
}
