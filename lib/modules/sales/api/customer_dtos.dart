import 'package:flutter/foundation.dart';

import '../domain/entities/customer_email.dart' show CustomerEmailPurpose;

export '../domain/entities/customer_email.dart' show CustomerEmailPurpose;

/// Contrato de lectura público para un cliente comercial.
@immutable
class CustomerDto {
  const CustomerDto({
    required this.id,
    required this.name,
    this.displayName,
    this.phone,
    this.email,
    this.address,
    this.taxId,
    this.countryCode = 'CR',
    this.province,
    this.city,
    this.gira,
    this.preferredCarrierId,
    this.identificationTypeId,
    this.economicActivity,
    this.customerType = 'CASH',
    this.creditDays,
    this.documentPreference = 'E_INVOICE',
    this.requiresEInvoice = false,
    this.deactivationReason,
    this.isActive = true,
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.shippingPaymentPolicy = 'INCLUDED',
    this.categoryIds = const [],
    this.categoryNames = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? displayName;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxId;
  final String countryCode;
  final String? province;
  final String? city;
  final String? gira;
  final String? preferredCarrierId;
  final String? identificationTypeId;
  final String? economicActivity;
  final String customerType;
  final int? creditDays;
  final String documentPreference;
  final bool requiresEInvoice;
  final String? deactivationReason;
  final bool isActive;
  final double creditLimit;
  final double currentBalance;
  final String shippingPaymentPolicy;
  final List<String> categoryIds;
  final List<String> categoryNames;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          displayName == other.displayName &&
          phone == other.phone &&
          email == other.email &&
          address == other.address &&
          taxId == other.taxId &&
          creditLimit == other.creditLimit &&
          currentBalance == other.currentBalance &&
          countryCode == other.countryCode &&
          province == other.province &&
          city == other.city &&
          gira == other.gira &&
          preferredCarrierId == other.preferredCarrierId &&
          identificationTypeId == other.identificationTypeId &&
          economicActivity == other.economicActivity &&
          customerType == other.customerType &&
          creditDays == other.creditDays &&
          documentPreference == other.documentPreference &&
          requiresEInvoice == other.requiresEInvoice &&
          deactivationReason == other.deactivationReason &&
          shippingPaymentPolicy == other.shippingPaymentPolicy &&
          listEquals(categoryIds, other.categoryIds) &&
          listEquals(categoryNames, other.categoryNames) &&
          isActive == other.isActive &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    displayName,
    phone,
    email,
    address,
    taxId,
    creditLimit,
    currentBalance,
    countryCode,
    province,
    city,
    gira,
    preferredCarrierId,
    identificationTypeId,
    economicActivity,
    customerType,
    creditDays,
    documentPreference,
    requiresEInvoice,
    deactivationReason,
    shippingPaymentPolicy,
    Object.hashAll(categoryIds),
    Object.hashAll(categoryNames),
    isActive,
    createdAt,
    updatedAt,
  ]);
}

/// Contrato de lectura público para una persona de contacto de un cliente.
@immutable
class CustomerContactDto {
  const CustomerContactDto({
    required this.id,
    required this.customerId,
    required this.name,
    this.phone,
    this.role,
    this.birthday,
  });

  final String id;
  final String customerId;
  final String name;
  final String? phone;
  final String? role;
  final DateTime? birthday;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerContactDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          customerId == other.customerId &&
          name == other.name &&
          phone == other.phone &&
          role == other.role &&
          birthday == other.birthday;

  @override
  int get hashCode => Object.hash(id, customerId, name, phone, role, birthday);
}

/// Contrato de lectura público para un correo electrónico documentario de cliente.
@immutable
class CustomerEmailDto {
  const CustomerEmailDto({
    required this.id,
    required this.customerId,
    required this.email,
    this.purpose = CustomerEmailPurpose.copy,
    this.label,
    this.isActive = true,
  });

  final String id;
  final String customerId;
  final String email;
  final CustomerEmailPurpose purpose;
  final String? label;
  final bool isActive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerEmailDto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          customerId == other.customerId &&
          email == other.email &&
          purpose == other.purpose &&
          label == other.label &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    email,
    purpose,
    label,
    isActive,
  );
}

/// Contrato de lectura público para un comprador de producto.
@immutable
class ProductBuyerDto {
  const ProductBuyerDto({
    required this.customerId,
    required this.name,
    this.phone,
    this.email,
    this.province,
    this.gira,
    this.isActive = true,
    this.lastPurchaseAt,
    this.totalQuantity = 0,
    this.documentsCount = 0,
    this.contacts = const [],
  });

  final String? customerId;
  final String name;
  final String? phone;
  final String? email;
  final String? province;
  final String? gira;
  final bool isActive;
  final DateTime? lastPurchaseAt;
  final int totalQuantity;
  final int documentsCount;
  final List<CustomerContactDto> contacts;

  bool matchesQuery(String query) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    if (terms.isEmpty) return true;
    final haystack = [
      name,
      phone,
      email,
      province,
      gira,
      for (final contact in contacts) ...[
        contact.name,
        contact.phone,
        contact.role,
      ],
    ].whereType<String>().join(' ').toLowerCase();
    return terms.every(haystack.contains);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductBuyerDto &&
          runtimeType == other.runtimeType &&
          customerId == other.customerId &&
          name == other.name &&
          phone == other.phone &&
          email == other.email &&
          province == other.province &&
          gira == other.gira &&
          isActive == other.isActive &&
          lastPurchaseAt == other.lastPurchaseAt &&
          totalQuantity == other.totalQuantity &&
          documentsCount == other.documentsCount &&
          listEquals(contacts, other.contacts);

  @override
  int get hashCode => Object.hashAll([
    customerId,
    name,
    phone,
    email,
    province,
    gira,
    isActive,
    lastPurchaseAt,
    totalQuantity,
    documentsCount,
    Object.hashAll(contacts),
  ]);
}

List<ProductBuyerDto> filterProductBuyers(
  List<ProductBuyerDto> buyers,
  String query,
) => buyers.where((buyer) => buyer.matchesQuery(query)).toList();
