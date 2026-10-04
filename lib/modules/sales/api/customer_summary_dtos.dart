import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_api.dart';

/// DTO para el producto frecuente que más compra el cliente (Decisión 36).
class FrequentProductDto {
  const FrequentProductDto({
    required this.productId,
    required this.productName,
    this.productSku,
    required this.totalQuantity,
    required this.purchaseCount,
  });

  factory FrequentProductDto.fromJson(Map<String, dynamic> json) =>
      FrequentProductDto(
        productId: json['product_id'] as String,
        productName: json['product_name'] as String? ?? 'Producto',
        productSku: json['product_sku'] as String?,
        totalQuantity: (json['total_quantity'] as num?)?.toInt() ?? 0,
        purchaseCount: (json['purchase_count'] as num?)?.toInt() ?? 0,
      );

  final String productId;
  final String productName;
  final String? productSku;
  final int totalQuantity;
  final int purchaseCount;
}

/// DTO de resumen comercial y financiero de un cliente.
class CustomerCommercialSummaryDto {
  const CustomerCommercialSummaryDto({
    required this.customerId,
    this.lastPurchaseAt,
    this.totalInvoiced = 0.0,
    this.confirmedOrdersCount = 0,
    this.pendingOrdersCount = 0,
    this.pendingQuotesCount = 0,
    this.pendingReturnsCount = 0,
    this.pendingConsignmentsCount = 0,
    this.totalPendingDocuments = 0,
    this.overdueInvoicesCount = 0,
    this.overdueInvoicesAmount = 0.0,
    this.frequentProducts = const [],
    this.categories = const [],
    this.commercialRankings = const [],
  });

  factory CustomerCommercialSummaryDto.empty(String customerId) =>
      CustomerCommercialSummaryDto(customerId: customerId);

  factory CustomerCommercialSummaryDto.fromJson(Map<String, dynamic> json) =>
      CustomerCommercialSummaryDto(
        customerId: json['customer_id'] as String,
        lastPurchaseAt: json['last_purchase_at'] != null
            ? DateTime.parse(json['last_purchase_at'] as String)
            : null,
        totalInvoiced: (json['total_invoiced'] as num?)?.toDouble() ?? 0.0,
        confirmedOrdersCount:
            (json['confirmed_orders_count'] as num?)?.toInt() ?? 0,
        pendingOrdersCount: (json['pending_orders_count'] as num?)?.toInt() ?? 0,
        pendingQuotesCount: (json['pending_quotes_count'] as num?)?.toInt() ?? 0,
        pendingReturnsCount:
            (json['pending_returns_count'] as num?)?.toInt() ?? 0,
        pendingConsignmentsCount:
            (json['pending_consignments_count'] as num?)?.toInt() ?? 0,
        totalPendingDocuments:
            (json['total_pending_documents'] as num?)?.toInt() ?? 0,
        overdueInvoicesCount:
            (json['overdue_invoices_count'] as num?)?.toInt() ?? 0,
        overdueInvoicesAmount:
            (json['overdue_invoices_amount'] as num?)?.toDouble() ?? 0.0,
        frequentProducts: (json['frequent_products'] as List<dynamic>?)
                ?.map((item) =>
                    FrequentProductDto.fromJson(item as Map<String, dynamic>))
                .toList() ??
            const [],
        categories: (json['categories'] as List<dynamic>?)
                ?.map((item) => CustomerCategorySummaryDto.fromJson(
                    item as Map<String, dynamic>))
                .toList() ??
            const [],
        commercialRankings: (json['commercial_rankings'] as List<dynamic>?)
                ?.map((item) => item.toString())
                .toList() ??
            const [],
      );

  final String customerId;
  final DateTime? lastPurchaseAt;
  final double totalInvoiced;
  final int confirmedOrdersCount;
  final int pendingOrdersCount;
  final int pendingQuotesCount;
  final int pendingReturnsCount;
  final int pendingConsignmentsCount;
  final int totalPendingDocuments;
  final int overdueInvoicesCount;
  final double overdueInvoicesAmount;
  final List<FrequentProductDto> frequentProducts;
  final List<CustomerCategorySummaryDto> categories;
  final List<String> commercialRankings;
}

class CustomerCategorySummaryDto {
  const CustomerCategorySummaryDto({
    required this.id,
    required this.name,
    this.color,
  });

  factory CustomerCategorySummaryDto.fromJson(Map<String, dynamic> json) =>
      CustomerCategorySummaryDto(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as String?,
      );

  final String id;
  final String name;
  final String? color;
}

/// Provider para obtener el resumen comercial y financiero de un cliente.
final customerCommercialSummaryProvider =
    FutureProvider.family<CustomerCommercialSummaryDto, String>(
  (ref, customerId) =>
      ref.watch(customerApiProvider).getCustomerCommercialSummary(customerId),
);
