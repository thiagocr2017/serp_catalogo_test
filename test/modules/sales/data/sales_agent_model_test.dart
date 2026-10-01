import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/sales/data/models/sales_agent_model.dart';

void main() {
  test('maps a Supabase agent row to the public sales model', () {
    final agent = SalesAgentModel.fromJson({
      'id': 'agent-1',
      'name': 'Ana',
      'phone': '+506 8888-8888',
      'is_active': true,
      'version': 3,
    }).toApi();

    expect(agent.id, 'agent-1');
    expect(agent.name, 'Ana');
    expect(agent.phone, '+506 8888-8888');
    expect(agent.version, 3);
  });
}
