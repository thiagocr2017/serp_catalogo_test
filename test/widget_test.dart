import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:serp/main.dart';

void main() {
  testWidgets('shows the product module shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SerpApp()));

    expect(find.text('Productos'), findsWidgets);
    expect(find.text('Nuevo producto'), findsOneWidget);
  });
}
