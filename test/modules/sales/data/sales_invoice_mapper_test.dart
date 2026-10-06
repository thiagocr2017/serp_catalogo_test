import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/sales/data/mappers/sales_dto_mapper.dart';
import 'package:serp/modules/sales/domain/entities/sales_invoice.dart';

void main() {
  test(
    'invoice mapper preserves persisted invoice lines in the public DTO',
    () {
      const invoice = SalesInvoice(
        id: 'invoice-1',
        invoiceNumber: 'FAC-0001',
        customerName: 'Tienda Demo',
        customerId: 'customer-1',
        status: SalesInvoiceStatus.confirmed,
        totalAmount: 25,
        currencyCode: 'CRC',
        lines: [
          SalesInvoiceLine(
            id: 'line-1',
            invoiceId: 'invoice-1',
            productId: 'product-1',
            productSku: 'SKU-1',
            productName: 'Producto Demo',
            quantity: 2,
            unitPrice: 12.5,
            totalPrice: 25,
          ),
        ],
      );

      final dto = invoice.toDto();

      expect(dto.lines, hasLength(1));
      expect(dto.lines.single.productId, 'product-1');
      expect(dto.lines.single.quantity, 2);
      expect(dto.lines.single.unitPrice, 12.5);
      expect(dto.lines.single.totalPrice, 25);
    },
  );
}
