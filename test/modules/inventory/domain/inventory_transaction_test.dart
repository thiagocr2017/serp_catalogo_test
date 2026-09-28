import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/inventory/domain/entities/inventory_transaction.dart';

void main() {
  test('sales are always negative', () {
    expect(
      signedInventoryQuantity(enteredQuantity: 5, reason: InventoryReason.sale),
      -5,
    );
    expect(
      signedInventoryQuantity(
        enteredQuantity: -5,
        reason: InventoryReason.sale,
      ),
      -5,
    );
  });

  test('adjustments preserve the entered sign', () {
    expect(
      signedInventoryQuantity(
        enteredQuantity: -5,
        reason: InventoryReason.adjustment,
      ),
      -5,
    );
    expect(
      signedInventoryQuantity(
        enteredQuantity: 5,
        reason: InventoryReason.adjustment,
      ),
      5,
    );
  });

  test('purchases and returns are always positive', () {
    expect(
      signedInventoryQuantity(
        enteredQuantity: -5,
        reason: InventoryReason.purchase,
      ),
      5,
    );
    expect(
      signedInventoryQuantity(
        enteredQuantity: -5,
        reason: InventoryReason.returnItem,
      ),
      5,
    );
  });
}
