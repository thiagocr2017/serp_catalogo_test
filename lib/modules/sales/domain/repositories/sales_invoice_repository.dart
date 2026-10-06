import '../entities/sales_invoice.dart';

abstract interface class SalesInvoiceRepository {
  Future<List<SalesInvoice>> getInvoices();
  Future<SalesInvoice?> getInvoiceById(String id);
  Future<SalesInvoice> createInvoice({
    required String customerId,
    required String customerName,
    required String currencyCode,
    required double exchangeRate,
    String? notes,
    required List<SalesInvoiceLineInput> lines,
    required String warehouseId,
  });
  Future<SalesInvoice> cancelInvoice(String id, {required String reason});
}

class SalesInvoiceLineInput {
  const SalesInvoiceLineInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    this.productSku,
    this.productName,
  });

  final String productId;
  final int quantity;
  final double unitPrice;
  final double discountPercent;
  final String? productSku;
  final String? productName;
}
