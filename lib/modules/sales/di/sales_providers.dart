import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/sales_repository.dart';

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => throw StateError('SalesRepository must be overridden.'),
);
