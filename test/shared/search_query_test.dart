import 'package:flutter_test/flutter_test.dart';
import 'package:serp/shared/utilities/search_query.dart';

void main() {
  test('activates only when input reaches three characters', () {
    expect(effectiveSearchQuery(' a '), isEmpty);
    expect(effectiveSearchQuery('ab'), isEmpty);
    expect(effectiveSearchQuery('abc'), 'abc');
  });

  test('clearing or deleting below threshold clears the active search', () {
    expect(effectiveSearchQuery(''), isEmpty);
    expect(effectiveSearchQuery('ab'), isEmpty);
  });

  test('counts Unicode code points and trims outer whitespace', () {
    expect(effectiveSearchQuery('  ñoñ  '), 'ñoñ');
  });
}
