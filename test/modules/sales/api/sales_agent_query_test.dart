import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/sales/api/sales_api.dart';

void main() {
  test('catalog consumers can request only active agents', () {
    const query = SalesAgentQuery(activeOnly: true);

    expect(query.activeOnly, isTrue);
  });

  test('administrative consumers include inactive agents by default', () {
    const query = SalesAgentQuery();

    expect(query.activeOnly, isFalse);
  });
}
