import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/sales/domain/entities/customer_commercial.dart';

void main() {
  const buyer = ProductBuyer(
    customerId: 'customer-1',
    name: 'Distribuidora El Sol',
    phone: '8888-1111',
    email: 'ventas@elsol.test',
    province: 'San José',
    gira: 'Gira Sur',
    totalQuantity: 24,
    documentsCount: 3,
    contacts: [
      CustomerContact(
        id: 'contact-1',
        customerId: 'customer-1',
        name: 'María Pérez',
        phone: '8888-2222',
        role: 'Compras',
      ),
    ],
  );
  const other = ProductBuyer(customerId: 'customer-2', name: 'Pulpería Norte');

  test('empty query matches everything', () {
    expect(filterProductBuyers([buyer, other], ''), [buyer, other]);
    expect(filterProductBuyers([buyer, other], '   '), [buyer, other]);
  });

  test('matches by business name', () {
    expect(filterProductBuyers([buyer, other], 'sol'), [buyer]);
  });

  test('matches by contact name, phone or role', () {
    expect(filterProductBuyers([buyer, other], 'maría'), [buyer]);
    expect(filterProductBuyers([buyer, other], '8888-2222'), [buyer]);
    expect(filterProductBuyers([buyer, other], 'compras'), [buyer]);
  });

  test('matches by province or gira', () {
    expect(filterProductBuyers([buyer, other], 'san josé'), [buyer]);
    expect(filterProductBuyers([buyer, other], 'gira sur'), [buyer]);
  });

  test('every term must match somewhere', () {
    expect(filterProductBuyers([buyer, other], 'sol compras'), [buyer]);
    expect(filterProductBuyers([buyer, other], 'sol heredia'), isEmpty);
  });

  test('match is case-insensitive', () {
    expect(filterProductBuyers([buyer, other], 'DISTRIBUIDORA'), [buyer]);
  });
}
