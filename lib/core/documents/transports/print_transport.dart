/// Tipo de canal o transporte físico de impresión.
enum PrintTransportType {
  /// Conexión cableada USB.
  usb,

  /// Conexión inalámbrica Bluetooth (SPP / BLE).
  bluetooth,

  /// Transporte simulado en memoria para pruebas.
  mock,
}

/// Contrato para el canal de comunicación con una impresora térmica.
abstract class PrintTransport {
  /// Tipo de conexión.
  PrintTransportType get type;

  /// Indica si el canal se encuentra actualmente conectado y disponible.
  bool get isConnected;

  /// Establece comunicación con el dispositivo de impresión.
  Future<void> connect();

  /// Transmite una secuencia de bytes binarios hacia el dispositivo.
  Future<void> send(List<int> bytes);

  /// Cierra la comunicación con el dispositivo.
  Future<void> disconnect();
}
