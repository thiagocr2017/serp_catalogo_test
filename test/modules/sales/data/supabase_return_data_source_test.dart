import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/device/device_identity.dart';
import 'package:serp/modules/sales/data/data_sources/supabase_return_data_source.dart';
import 'package:serp/modules/sales/domain/repositories/return_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('no invoca la RPC heredada para crear devoluciones', () {
    final source = SupabaseReturnDataSource(
      SupabaseClient('http://localhost:54321', 'test-key'),
      const DeviceIdentity(name: 'test-device', identifier: 'test-id'),
    );

    expect(
      () => source.createReturn(
        invoiceId: 'invoice-1',
        customerId: 'customer-1',
        customerName: 'Cliente',
        reason: 'Prueba',
        lines: const [
          ReturnLineInput(
            productId: 'product-1',
            invoiceLineId: 'invoice-line-1',
            quantity: 1,
            unitPrice: 10,
          ),
        ],
      ),
      throwsUnsupportedError,
    );
  });
}
