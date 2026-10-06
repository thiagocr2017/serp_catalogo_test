/// Desglose de impuesto individual por nombre o tasa.
class DocumentTaxItem {
  const DocumentTaxItem({
    required this.name,
    required this.rate,
    required this.amount,
  });

  /// Nombre del impuesto (ej: IVA 13%, IVA 4%, Exento).
  final String name;

  /// Tasa porcentual (ej: 0.13).
  final double rate;

  /// Monto total liquidado por este impuesto.
  final double amount;
}

/// Totales monetarios, impuestos y moneda de un documento.
class DocumentTotals {
  const DocumentTotals({
    required this.subtotal,
    required this.grandTotal,
    this.currencyCode = 'CRC',
    this.currencySymbol = '₡',
    this.discountTotal = 0.0,
    this.taxTotal = 0.0,
    this.taxBreakdown = const [],
    this.rounding = 0.0,
    this.exchangeRate,
  });

  /// Código ISO de la moneda (ej: CRC, USD).
  final String currencyCode;

  /// Símbolo visual de la moneda (ej: ₡, $).
  final String currencySymbol;

  /// Subtotal de las líneas antes de descuentos e impuestos.
  final double subtotal;

  /// Suma global de descuentos aplicados.
  final double discountTotal;

  /// Suma global de impuestos calculados.
  final double taxTotal;

  /// Desglose opcional de impuestos por tasa.
  final List<DocumentTaxItem> taxBreakdown;

  /// Ajuste por redondeo al cierre.
  final double rounding;

  /// Total neto final del documento.
  final double grandTotal;

  /// Tipo de cambio histórico (si aplica para transacciones bimonetarias).
  final double? exchangeRate;

  /// Formatea un valor monetario agregando el símbolo y dos decimales.
  String formatAmount(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    final count = intPart.length;
    for (int i = 0; i < count; i++) {
      if (i > 0 && (count - i) % 3 == 0 && intPart[i - 1] != '-') {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }

    return '$currencySymbol${buffer.toString()}.$decPart';
  }
}
