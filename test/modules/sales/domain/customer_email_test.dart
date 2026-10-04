import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/sales/domain/entities/customer_email.dart';

void main() {
  group('CustomerEmailPurpose', () {
    test('serializa PRIMARY y COPY', () {
      expect(CustomerEmailPurpose.primary.toJson(), 'PRIMARY');
      expect(CustomerEmailPurpose.copy.toJson(), 'COPY');
    });

    test('deserializa PRIMARY y COPY', () {
      expect(
        CustomerEmailPurpose.fromJson('PRIMARY'),
        CustomerEmailPurpose.primary,
      );
      expect(CustomerEmailPurpose.fromJson('COPY'), CustomerEmailPurpose.copy);
    });

    test('valor desconocido cae en COPY', () {
      expect(
        CustomerEmailPurpose.fromJson('OTRO'),
        CustomerEmailPurpose.copy,
      );
    });
  });

  group('CustomerEmail', () {
    test('copia es el proposito por defecto', () {
      const email = CustomerEmail(
        id: 'email-1',
        customerId: 'customer-1',
        email: 'a@example.com',
      );
      expect(email.purpose, CustomerEmailPurpose.copy);
      expect(email.isActive, true);
    });

    test('guarda todos los campos', () {
      const email = CustomerEmail(
        id: 'email-2',
        customerId: 'customer-1',
        email: 'principal@example.com',
        purpose: CustomerEmailPurpose.primary,
        label: 'Facturacion',
        isActive: false,
      );
      expect(email.email, 'principal@example.com');
      expect(email.purpose, CustomerEmailPurpose.primary);
      expect(email.label, 'Facturacion');
      expect(email.isActive, false);
    });
  });
}
