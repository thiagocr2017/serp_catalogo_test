import 'package:flutter/foundation.dart';

import '../domain/entities/sales_consignment.dart' show ConsignmentStatus;
import '../domain/entities/sales_invoice.dart' show SalesInvoiceStatus;
import '../domain/entities/sales_order.dart' show OrderStatus;
import '../domain/entities/sales_quote.dart' show QuoteStatus;
import '../domain/entities/sales_return.dart' show ReturnStatus;

export '../domain/entities/sales_consignment.dart' show ConsignmentStatus;
export '../domain/entities/sales_invoice.dart' show SalesInvoiceStatus;
export '../domain/entities/sales_order.dart' show OrderStatus;
export '../domain/entities/sales_quote.dart' show QuoteStatus;
export '../domain/entities/sales_return.dart' show ReturnStatus;

// ---------------------------------------------------------------------------
// Line inputs para comandos / RPCs de creación de documentos
// ---------------------------------------------------------------------------

@immutable
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

@immutable
class QuoteLineInput {
  const QuoteLineInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    this.productSku,
    this.productName,
    this.presentationName,
    this.unitsPerPresentation = 1,
  });

  final String productId;
  final int quantity;
  final double unitPrice;
  final double discountPercent;
  final String? productSku;
  final String? productName;
  final String? presentationName;
  final int unitsPerPresentation;
}

@immutable
class OrderLineInput {
  const OrderLineInput({
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

@immutable
class ReturnLineInput {
  const ReturnLineInput({
    required this.productId,
    required this.invoiceLineId,
    required this.quantity,
    required this.unitPrice,
    this.condition = 'GOOD',
    this.conditionNote,
    this.locationId,
    this.productSku,
    this.productName,
  });

  final String productId;
  final String invoiceLineId;
  final int quantity;
  final double unitPrice;
  final String condition;
  final String? conditionNote;
  final String? locationId;
  final String? productSku;
  final String? productName;
}

@immutable
class ConsignmentLineInput {
  const ConsignmentLineInput({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.productSku,
    this.productName,
  });

  final String productId;
  final int quantity;
  final double unitPrice;
  final String? productSku;
  final String? productName;
}

// ---------------------------------------------------------------------------
// Facturas de venta (Sales Invoice)
// ---------------------------------------------------------------------------

@immutable
class SalesInvoiceDto {
  const SalesInvoiceDto({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    this.customerId,
    this.sourceQuoteId,
    this.exchangeRate = 1.0,
    this.notes,
    this.inventoryDocumentId,
    this.lines = const [],
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
    this.debtReductionAmount = 0,
    this.financialResolution,
    this.financialResolutionAmount = 0,
    this.cancelledAt,
  });

  final String id;
  final String invoiceNumber;
  final String customerName;
  final SalesInvoiceStatus status;
  final double totalAmount;
  final String currencyCode;
  final String? customerId;
  final String? sourceQuoteId;
  final double exchangeRate;
  final String? notes;
  final String? inventoryDocumentId;
  final List<SalesInvoiceLineDto> lines;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
  final double debtReductionAmount;
  final String? financialResolution;
  final double financialResolutionAmount;
  final DateTime? cancelledAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesInvoiceDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          invoiceNumber == other.invoiceNumber &&
          customerName == other.customerName &&
          status == other.status &&
          totalAmount == other.totalAmount &&
          currencyCode == other.currencyCode &&
          customerId == other.customerId &&
          sourceQuoteId == other.sourceQuoteId &&
          exchangeRate == other.exchangeRate &&
          notes == other.notes &&
          inventoryDocumentId == other.inventoryDocumentId &&
          listEquals(lines, other.lines) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          confirmedAt == other.confirmedAt &&
          cancelledAt == other.cancelledAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    invoiceNumber,
    customerName,
    status,
    totalAmount,
    currencyCode,
    customerId,
    sourceQuoteId,
    exchangeRate,
    notes,
    inventoryDocumentId,
    Object.hashAll(lines),
    createdAt,
    updatedAt,
    confirmedAt,
    cancelledAt,
  ]);
}

@immutable
class SalesInvoiceLineDto {
  const SalesInvoiceLineDto({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.discountPercent = 0,
    this.productSku,
    this.productName,
  });

  final String id;
  final String invoiceId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double discountPercent;
  final String? productSku;
  final String? productName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesInvoiceLineDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          invoiceId == other.invoiceId &&
          productId == other.productId &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice &&
          totalPrice == other.totalPrice &&
          discountPercent == other.discountPercent &&
          productSku == other.productSku &&
          productName == other.productName;

  @override
  int get hashCode => Object.hash(
    id,
    invoiceId,
    productId,
    quantity,
    unitPrice,
    totalPrice,
    discountPercent,
    productSku,
    productName,
  );
}

// ---------------------------------------------------------------------------
// Cotizaciones (Sales Quote)
// ---------------------------------------------------------------------------

@immutable
class SalesQuoteDto {
  const SalesQuoteDto({
    required this.id,
    required this.quoteNumber,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    this.customerId,
    this.exchangeRate = 1.0,
    this.validUntil,
    this.notes,
    this.agentId,
    this.convertedInvoiceId,
    this.lines = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String quoteNumber;
  final String customerName;
  final QuoteStatus status;
  final double totalAmount;
  final String currencyCode;
  final String? customerId;
  final double exchangeRate;
  final DateTime? validUntil;
  final String? notes;
  final String? agentId;
  final String? convertedInvoiceId;
  final List<SalesQuoteLineDto> lines;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesQuoteDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          quoteNumber == other.quoteNumber &&
          customerName == other.customerName &&
          status == other.status &&
          totalAmount == other.totalAmount &&
          currencyCode == other.currencyCode &&
          customerId == other.customerId &&
          exchangeRate == other.exchangeRate &&
          validUntil == other.validUntil &&
          notes == other.notes &&
          agentId == other.agentId &&
          convertedInvoiceId == other.convertedInvoiceId &&
          listEquals(lines, other.lines) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    quoteNumber,
    customerName,
    status,
    totalAmount,
    currencyCode,
    customerId,
    exchangeRate,
    validUntil,
    notes,
    agentId,
    convertedInvoiceId,
    Object.hashAll(lines),
    createdAt,
    updatedAt,
  ]);
}

@immutable
class SalesQuoteLineDto {
  const SalesQuoteLineDto({
    required this.id,
    required this.quoteId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.discountPercent = 0,
    this.productSku,
    this.productName,
    this.presentationName,
    this.unitsPerPresentation = 1,
  });

  final String id;
  final String quoteId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double discountPercent;
  final String? productSku;
  final String? productName;
  final String? presentationName;
  final int unitsPerPresentation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesQuoteLineDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          quoteId == other.quoteId &&
          productId == other.productId &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice &&
          totalPrice == other.totalPrice &&
          discountPercent == other.discountPercent &&
          productSku == other.productSku &&
          productName == other.productName &&
          presentationName == other.presentationName &&
          unitsPerPresentation == other.unitsPerPresentation;

  @override
  int get hashCode => Object.hash(
    id,
    quoteId,
    productId,
    quantity,
    unitPrice,
    totalPrice,
    discountPercent,
    productSku,
    productName,
    presentationName,
    unitsPerPresentation,
  );
}

// ---------------------------------------------------------------------------
// Pedidos (Sales Order)
// ---------------------------------------------------------------------------

@immutable
class SalesOrderDto {
  const SalesOrderDto({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    this.customerId,
    this.exchangeRate = 1.0,
    this.notes,
    this.agentId,
    this.quoteId,
    this.inventoryDocumentId,
    this.lines = const [],
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
    this.cancelledAt,
  });

  final String id;
  final String orderNumber;
  final String customerName;
  final OrderStatus status;
  final double totalAmount;
  final String currencyCode;
  final String? customerId;
  final double exchangeRate;
  final String? notes;
  final String? agentId;
  final String? quoteId;
  final String? inventoryDocumentId;
  final List<SalesOrderLineDto> lines;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesOrderDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderNumber == other.orderNumber &&
          customerName == other.customerName &&
          status == other.status &&
          totalAmount == other.totalAmount &&
          currencyCode == other.currencyCode &&
          customerId == other.customerId &&
          exchangeRate == other.exchangeRate &&
          notes == other.notes &&
          agentId == other.agentId &&
          quoteId == other.quoteId &&
          inventoryDocumentId == other.inventoryDocumentId &&
          listEquals(lines, other.lines) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          confirmedAt == other.confirmedAt &&
          cancelledAt == other.cancelledAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    orderNumber,
    customerName,
    status,
    totalAmount,
    currencyCode,
    customerId,
    exchangeRate,
    notes,
    agentId,
    quoteId,
    inventoryDocumentId,
    Object.hashAll(lines),
    createdAt,
    updatedAt,
    confirmedAt,
    cancelledAt,
  ]);
}

@immutable
class SalesOrderLineDto {
  const SalesOrderLineDto({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.discountPercent = 0,
    this.productSku,
    this.productName,
  });

  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double discountPercent;
  final String? productSku;
  final String? productName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesOrderLineDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          orderId == other.orderId &&
          productId == other.productId &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice &&
          totalPrice == other.totalPrice &&
          discountPercent == other.discountPercent &&
          productSku == other.productSku &&
          productName == other.productName;

  @override
  int get hashCode => Object.hash(
    id,
    orderId,
    productId,
    quantity,
    unitPrice,
    totalPrice,
    discountPercent,
    productSku,
    productName,
  );
}

// ---------------------------------------------------------------------------
// Devoluciones (Sales Return)
// ---------------------------------------------------------------------------

@immutable
class SalesReturnDto {
  const SalesReturnDto({
    required this.id,
    required this.returnNumber,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    required this.reason,
    this.invoiceId,
    this.customerId,
    this.notes,
    this.inventoryDocumentId,
    this.lines = const [],
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
    this.debtReductionAmount = 0,
    this.financialResolution,
    this.financialResolutionAmount = 0,
  });

  final String id;
  final String returnNumber;
  final String customerName;
  final ReturnStatus status;
  final double totalAmount;
  final String currencyCode;
  final String reason;
  final String? invoiceId;
  final String? customerId;
  final String? notes;
  final String? inventoryDocumentId;
  final List<SalesReturnLineDto> lines;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;
  final double debtReductionAmount;
  final String? financialResolution;
  final double financialResolutionAmount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesReturnDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          returnNumber == other.returnNumber &&
          customerName == other.customerName &&
          status == other.status &&
          totalAmount == other.totalAmount &&
          currencyCode == other.currencyCode &&
          reason == other.reason &&
          invoiceId == other.invoiceId &&
          customerId == other.customerId &&
          notes == other.notes &&
          inventoryDocumentId == other.inventoryDocumentId &&
          listEquals(lines, other.lines) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          confirmedAt == other.confirmedAt &&
          debtReductionAmount == other.debtReductionAmount &&
          financialResolution == other.financialResolution &&
          financialResolutionAmount == other.financialResolutionAmount;

  @override
  int get hashCode => Object.hashAll([
    id,
    returnNumber,
    customerName,
    status,
    totalAmount,
    currencyCode,
    reason,
    invoiceId,
    customerId,
    notes,
    inventoryDocumentId,
    Object.hashAll(lines),
    createdAt,
    updatedAt,
    confirmedAt,
    debtReductionAmount,
    financialResolution,
    financialResolutionAmount,
  ]);
}

@immutable
class SalesReturnLineDto {
  const SalesReturnLineDto({
    required this.id,
    required this.returnId,
    required this.productId,
    this.invoiceLineId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.productSku,
    this.productName,
    this.condition = 'GOOD',
    this.conditionNote,
    this.inventoryLocationId,
  });

  final String id;
  final String returnId;
  final String productId;
  final String? invoiceLineId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? productSku;
  final String? productName;
  final String condition;
  final String? conditionNote;
  final String? inventoryLocationId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesReturnLineDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          returnId == other.returnId &&
          productId == other.productId &&
          invoiceLineId == other.invoiceLineId &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice &&
          totalPrice == other.totalPrice &&
          productSku == other.productSku &&
          productName == other.productName &&
          condition == other.condition &&
          conditionNote == other.conditionNote &&
          inventoryLocationId == other.inventoryLocationId;

  @override
  int get hashCode => Object.hash(
    id,
    returnId,
    productId,
    quantity,
    unitPrice,
    totalPrice,
    productSku,
    productName,
    condition,
    conditionNote,
    inventoryLocationId,
  );
}

// ---------------------------------------------------------------------------
// Consignaciones (Sales Consignment)
// ---------------------------------------------------------------------------

@immutable
class SalesConsignmentDto {
  const SalesConsignmentDto({
    required this.id,
    required this.consignmentNumber,
    required this.customerName,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    this.customerId,
    this.returnedAmount = 0,
    this.notes,
    this.agentId,
    this.inventoryDocumentId,
    this.lines = const [],
    this.createdAt,
    this.updatedAt,
    this.confirmedAt,
  });

  final String id;
  final String consignmentNumber;
  final String customerName;
  final ConsignmentStatus status;
  final double totalAmount;
  final String currencyCode;
  final String? customerId;
  final double returnedAmount;
  final String? notes;
  final String? agentId;
  final String? inventoryDocumentId;
  final List<SalesConsignmentLineDto> lines;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? confirmedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesConsignmentDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          consignmentNumber == other.consignmentNumber &&
          customerName == other.customerName &&
          status == other.status &&
          totalAmount == other.totalAmount &&
          currencyCode == other.currencyCode &&
          customerId == other.customerId &&
          returnedAmount == other.returnedAmount &&
          notes == other.notes &&
          agentId == other.agentId &&
          inventoryDocumentId == other.inventoryDocumentId &&
          listEquals(lines, other.lines) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          confirmedAt == other.confirmedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    consignmentNumber,
    customerName,
    status,
    totalAmount,
    currencyCode,
    customerId,
    returnedAmount,
    notes,
    agentId,
    inventoryDocumentId,
    Object.hashAll(lines),
    createdAt,
    updatedAt,
    confirmedAt,
  ]);
}

@immutable
class SalesConsignmentLineDto {
  const SalesConsignmentLineDto({
    required this.id,
    required this.consignmentId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.returnedQuantity = 0,
    this.productSku,
    this.productName,
  });

  final String id;
  final String consignmentId;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final int returnedQuantity;
  final String? productSku;
  final String? productName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesConsignmentLineDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          consignmentId == other.consignmentId &&
          productId == other.productId &&
          quantity == other.quantity &&
          unitPrice == other.unitPrice &&
          totalPrice == other.totalPrice &&
          returnedQuantity == other.returnedQuantity &&
          productSku == other.productSku &&
          productName == other.productName;

  @override
  int get hashCode => Object.hash(
    id,
    consignmentId,
    productId,
    quantity,
    unitPrice,
    totalPrice,
    returnedQuantity,
    productSku,
    productName,
  );
}
