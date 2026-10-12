import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:serp/modules/inventory/data/data_sources/supabase_inventory_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'product and category labels split large ID sets into bounded requests',
    () async {
      final requestedUris = <Uri>[];
      final client = SupabaseClient(
        'http://localhost:54321',
        'test-key',
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);
          return http.Response(
            jsonEncode([]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final dataSource = SupabaseInventoryDataSource(client);
      final ids = [for (var index = 0; index < 205; index++) 'id-$index'];

      await dataSource.productLabels(ids);
      await dataSource.categoryLabels(ids);

      expect(requestedUris, hasLength(6));
      for (final uri in requestedUris) {
        final values = uri.queryParameters.values.singleWhere(
          (value) => value.startsWith('in.'),
        );
        final idsInRequest = values.substring(4, values.length - 1).split(',');
        expect(idsInRequest.length, lessThanOrEqualTo(100));
      }
      expect(
        requestedUris.where((uri) => uri.path.endsWith('/products')),
        hasLength(3),
      );
      expect(
        requestedUris.where((uri) => uri.path.endsWith('/categories')),
        hasLength(3),
      );
    },
  );
}
