/// Representa un renglón o línea operativa del documento.
class DocumentLine {
  const DocumentLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.itemCode,
    this.unit = 'UND',
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    this.taxRate = 0.0,
    this.notes,
  });

  /// Código de producto o SKU (opcional).
  final String? itemCode;

  /// Descripción detallada o nombre del producto o servicio.
  final String description;

  /// Cantidad registrada (soporta enteros y fracciones para peso/volumen).
  final double quantity;

  /// Unidad de medida (ej: UND, KG, MTR, PAQ).
  final String? unit;

  /// Precio unitario registrado.
  final double unitPrice;

  /// Monto total de descuento aplicado en esta línea.
  final double discountAmount;

  /// Monto de impuesto en esta línea.
  final double taxAmount;

  /// Tasa porcentual de impuesto (ej: 0.13 para 13%).
  final double taxRate;

  /// Importe neto total de la línea.
  final double total;

  /// Nota o detalle específico de la línea (lote, serie, garantía).
  final String? notes;

  /// Texto formateado de la cantidad (omite .00 si es entero exacto).
  String get formattedQuantity {
    if (quantity == quantity.roundToDouble()) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(2);
  }
}
