import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => throw StateError('PaymentRepository must be overridden.'),
);
