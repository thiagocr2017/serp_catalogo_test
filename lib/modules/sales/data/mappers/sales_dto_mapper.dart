import '../../api/customer_dtos.dart';
import '../../api/sales_document_dtos.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_commercial.dart';
import '../../domain/entities/customer_email.dart';
import '../../domain/entities/sales_consignment.dart';
import '../../domain/entities/sales_invoice.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/entities/sales_quote.dart';
import '../../domain/entities/sales_return.dart';

extension CustomerMapper on Customer {
  CustomerDto toDto() => CustomerDto(
    id: id,
    name: name,
    displayName: displayName,
    phone: phone,
    email: email,
    address: address,
    taxId: taxId,
    creditLimit: creditLimit,
    countryCode: countryCode,
    province: province,
    city: city,
    gira: gira,
    preferredCarrierId: preferredCarrierId,
    identificationTypeId: identificationTypeId,
    economicActivity: economicActivity,
    customerType: customerType,
    creditDays: creditDays,
    documentPreference: documentPreference,
    requiresEInvoice: requiresEInvoice,
    currentBalance: currentBalance,
    shippingPaymentPolicy: shippingPaymentPolicy,
    categoryIds: categoryIds,
    categoryNames: categoryNames,
    deactivationReason: deactivationReason,
    isActive: isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension CustomerContactMapper on CustomerContact {
  CustomerContactDto toDto() => CustomerContactDto(
    id: id,
    customerId: customerId,
    name: name,
    phone: phone,
    role: role,
    birthday: birthday,
  );
}

extension CustomerEmailMapper on CustomerEmail {
  CustomerEmailDto toDto() => CustomerEmailDto(
    id: id,
    customerId: customerId,
    email: email,
    purpose: purpose,
    label: label,
    isActive: isActive,
  );
}

extension ProductBuyerMapper on ProductBuyer {
  ProductBuyerDto toDto() => ProductBuyerDto(
    customerId: customerId,
    name: name,
    phone: phone,
    email: email,
    province: province,
    gira: gira,
    isActive: isActive,
    lastPurchaseAt: lastPurchaseAt,
    totalQuantity: totalQuantity,
    documentsCount: documentsCount,
    contacts: contacts.map((c) => c.toDto()).toList(),
  );
}

extension SalesInvoiceLineMapper on SalesInvoiceLine {
  SalesInvoiceLineDto toDto() => SalesInvoiceLineDto(
    id: id,
    invoiceId: invoiceId,
    productId: productId,
    quantity: quantity,
    unitPrice: unitPrice,
    totalPrice: totalPrice,
    discountPercent: discountPercent,
    productSku: productSku,
    productName: productName,
  );
}

extension SalesInvoiceMapper on SalesInvoice {
  SalesInvoiceDto toDto({List<SalesInvoiceLine>? lines}) => SalesInvoiceDto(
    id: id,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
    status: status,
    totalAmount: totalAmount,
    currencyCode: currencyCode,
    customerId: customerId,
    exchangeRate: exchangeRate,
    notes: notes,
    inventoryDocumentId: inventoryDocumentId,
    lines: (lines ?? this.lines).map((l) => l.toDto()).toList(),
    createdAt: createdAt,
    updatedAt: updatedAt,
    confirmedAt: confirmedAt,
    cancelledAt: cancelledAt,
  );
}

extension SalesQuoteLineMapper on SalesQuoteLine {
  SalesQuoteLineDto toDto() => SalesQuoteLineDto(
    id: id,
    quoteId: quoteId,
    productId: productId,
    quantity: quantity,
    unitPrice: unitPrice,
    totalPrice: totalPrice,
    discountPercent: discountPercent,
    productSku: productSku,
    productName: productName,
    presentationName: presentationName,
    unitsPerPresentation: unitsPerPresentation,
  );
}

extension SalesQuoteMapper on SalesQuote {
  SalesQuoteDto toDto({List<SalesQuoteLine>? lines}) => SalesQuoteDto(
    id: id,
    quoteNumber: quoteNumber,
    customerName: customerName,
    status: status,
    totalAmount: totalAmount,
    currencyCode: currencyCode,
    customerId: customerId,
    exchangeRate: exchangeRate,
    validUntil: validUntil,
    notes: notes,
    agentId: agentId,
    lines: (lines ?? this.lines).map((l) => l.toDto()).toList(),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension SalesOrderLineMapper on SalesOrderLine {
  SalesOrderLineDto toDto() => SalesOrderLineDto(
    id: id,
    orderId: orderId,
    productId: productId,
    quantity: quantity,
    unitPrice: unitPrice,
    totalPrice: totalPrice,
    discountPercent: discountPercent,
    productSku: productSku,
    productName: productName,
  );
}

extension SalesOrderMapper on SalesOrder {
  SalesOrderDto toDto({List<SalesOrderLine> lines = const []}) => SalesOrderDto(
    id: id,
    orderNumber: orderNumber,
    customerName: customerName,
    status: status,
    totalAmount: totalAmount,
    currencyCode: currencyCode,
    customerId: customerId,
    exchangeRate: exchangeRate,
    notes: notes,
    agentId: agentId,
    quoteId: quoteId,
    inventoryDocumentId: inventoryDocumentId,
    lines: lines.map((l) => l.toDto()).toList(),
    createdAt: createdAt,
    updatedAt: updatedAt,
    confirmedAt: confirmedAt,
    cancelledAt: cancelledAt,
  );
}

extension SalesReturnLineMapper on SalesReturnLine {
  SalesReturnLineDto toDto() => SalesReturnLineDto(
    id: id,
    returnId: returnId,
    productId: productId,
    invoiceLineId: invoiceLineId,
    quantity: quantity,
    unitPrice: unitPrice,
    totalPrice: totalPrice,
    productSku: productSku,
    productName: productName,
    condition: condition,
    inventoryLocationId: inventoryLocationId,
  );
}

extension SalesReturnMapper on SalesReturn {
  SalesReturnDto toDto() => SalesReturnDto(
    id: id,
    returnNumber: returnNumber,
    customerName: customerName,
    status: status,
    totalAmount: totalAmount,
    currencyCode: currencyCode,
    reason: reason,
    invoiceId: invoiceId,
    customerId: customerId,
    notes: notes,
    inventoryDocumentId: inventoryDocumentId,
    lines: lines.map((l) => l.toDto()).toList(),
    createdAt: createdAt,
    updatedAt: updatedAt,
    confirmedAt: confirmedAt,
    debtReductionAmount: debtReductionAmount,
    financialResolution: financialResolution,
    financialResolutionAmount: financialResolutionAmount,
  );
}

extension SalesConsignmentLineMapper on SalesConsignmentLine {
  SalesConsignmentLineDto toDto() => SalesConsignmentLineDto(
    id: id,
    consignmentId: consignmentId,
    productId: productId,
    quantity: quantity,
    unitPrice: unitPrice,
    totalPrice: totalPrice,
    returnedQuantity: returnedQuantity,
    productSku: productSku,
    productName: productName,
  );
}

extension SalesConsignmentMapper on SalesConsignment {
  SalesConsignmentDto toDto({List<SalesConsignmentLine>? lines}) =>
      SalesConsignmentDto(
        id: id,
        consignmentNumber: consignmentNumber,
        customerName: customerName,
        status: status,
        totalAmount: totalAmount,
        currencyCode: currencyCode,
        customerId: customerId,
        returnedAmount: returnedAmount,
        notes: notes,
        agentId: agentId,
        inventoryDocumentId: inventoryDocumentId,
        lines: (lines ?? this.lines).map((l) => l.toDto()).toList(),
        createdAt: createdAt,
        updatedAt: updatedAt,
        confirmedAt: confirmedAt,
      );
}
