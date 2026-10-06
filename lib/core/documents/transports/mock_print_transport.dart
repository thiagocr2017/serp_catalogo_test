import 'print_transport.dart';

/// Implementación en memoria de [PrintTransport] para pruebas unitarias y de integración.
class MockPrintTransport implements PrintTransport {
  MockPrintTransport({
    this.shouldFailConnection = false,
    this.shouldFailSend = false,
  });

  bool shouldFailConnection;
  bool shouldFailSend;

  bool _connected = false;
  final List<List<int>> _sentPayloads = [];

  @override
  PrintTransportType get type => PrintTransportType.mock;

  @override
  bool get isConnected => _connected;

  /// Historial de cargas enviadas durante la sesión.
  List<List<int>> get sentPayloads => List.unmodifiable(_sentPayloads);

  /// Cantidad total de bytes transmitidos.
  int get totalBytesSent =>
      _sentPayloads.fold<int>(0, (sum, payload) => sum + payload.length);

  @override
  Future<void> connect() async {
    if (shouldFailConnection) {
      throw StateError('Error simulado al conectar con la impresora');
    }
    _connected = true;
  }

  @override
  Future<void> send(List<int> bytes) async {
    if (!_connected) {
      throw StateError('No se puede enviar datos a una impresora desconectada');
    }
    if (shouldFailSend) {
      throw StateError('Error simulado de comunicación durante el envío');
    }
    _sentPayloads.add(List<int>.from(bytes));
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  /// Limpia las cargas registradas.
  void clear() {
    _sentPayloads.clear();
  }
}
