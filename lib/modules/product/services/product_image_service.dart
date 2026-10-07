import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as image;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

enum ProductImageFrame {
  vertical(4 / 5),
  horizontal(4 / 3);

  const ProductImageFrame(this.aspectRatio);
  final double aspectRatio;
}

class ProductImageService {
  const ProductImageService(this._client);
  final SupabaseClient _client;

  /// Decodifica o falla con un error legible: el paquete image puede
  /// lanzar errores crudos (p. ej. RangeError) con archivos inválidos.
  static image.Image _decoded(Uint8List bytes) {
    try {
      final decoded = image.decodeImage(bytes);
      if (decoded != null) return decoded;
    } catch (_) {
      // Se convierte abajo en FormatException.
    }
    throw const FormatException('La imagen seleccionada no es válida.');
  }

  /// Dimensiones en píxeles de una imagen ya cargada en memoria.
  static ({int width, int height}) dimensionsOf(Uint8List bytes) {
    final decoded = _decoded(bytes);
    return (width: decoded.width, height: decoded.height);
  }

  /// Ventana de recorte en píxeles para un punto focal (0..1) y zoom
  /// (1..3). El zoom 1 abarca la imagen completa; valores mayores recortan
  /// alrededor del punto focal, limitado a los bordes.
  static ({int x, int y, int width, int height}) cropWindow(
    int imageWidth,
    int imageHeight, {
    required double focalX,
    required double focalY,
    required double zoom,
    ProductImageFrame? frame,
  }) {
    final z = zoom.clamp(1, 3).toDouble();
    var baseWidth = imageWidth.toDouble();
    var baseHeight = imageHeight.toDouble();
    if (frame != null) {
      final sourceAspect = imageWidth / imageHeight;
      if (sourceAspect > frame.aspectRatio) {
        baseWidth = imageHeight * frame.aspectRatio;
      } else {
        baseHeight = imageWidth / frame.aspectRatio;
      }
    }
    final width = (baseWidth / z).round().clamp(1, imageWidth);
    final height = (baseHeight / z).round().clamp(1, imageHeight);
    final x = (focalX * imageWidth - width / 2).round().clamp(
      0,
      imageWidth - width,
    );
    final y = (focalY * imageHeight - height / 2).round().clamp(
      0,
      imageHeight - height,
    );
    return (x: x, y: y, width: width, height: height);
  }

  /// Aplica el encuadre elegido y devuelve los bytes recortados listos para
  /// subir. La imagen guardada ya queda enmarcada, por lo que debe
  /// persistirse con parámetros neutros (0.5, 0.5, 1) para que todas las
  /// vistas la muestren tal cual.
  static Uint8List applyFraming(
    Uint8List bytes, {
    required double focalX,
    required double focalY,
    required double zoom,
    ProductImageFrame? frame,
  }) {
    final decoded = _decoded(bytes);
    final window = cropWindow(
      decoded.width,
      decoded.height,
      focalX: focalX,
      focalY: focalY,
      zoom: zoom,
      frame: frame,
    );
    final cropped = image.copyCrop(
      decoded,
      x: window.x,
      y: window.y,
      width: window.width,
      height: window.height,
    );
    return Uint8List.fromList(image.encodeJpg(cropped, quality: 82));
  }

  static Uint8List rotateQuarterTurn(Uint8List bytes, {required int turns}) {
    final decoded = _decoded(bytes);
    final normalizedTurns = turns % 4;
    if (normalizedTurns == 0) return bytes;
    final rotated = image.copyRotate(decoded, angle: normalizedTurns * 90);
    return Uint8List.fromList(image.encodeJpg(rotated, quality: 82));
  }

  Future<Uint8List> loadExisting(String publicUrl) async {
    final path = _storagePath(publicUrl);
    if (path == null) {
      throw const FormatException(
        'La URL no corresponde a una imagen del almacenamiento de productos.',
      );
    }
    return _client.storage.from('product-images').download(path);
  }

  Future<Uint8List?> selectAndCompress() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Imágenes',
          extensions: ['jpg', 'jpeg', 'png', 'webp'],
        ),
      ],
    );
    if (file == null) return null;
    final decoded = _decoded(await file.readAsBytes());
    final resized = decoded.width > 1600
        ? image.copyResize(decoded, width: 1600)
        : decoded;
    return Uint8List.fromList(image.encodeJpg(resized, quality: 82));
  }

  Future<String> replace({
    required String sku,
    required Uint8List bytes,
  }) async {
    final safeSku = sku
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (safeSku.isEmpty) {
      throw const FormatException(
        'El SKU no permite crear un nombre de imagen.',
      );
    }
    final path =
        '$safeSku-${DateTime.now().microsecondsSinceEpoch}-${const Uuid().v4()}.jpg';
    await _client.storage
        .from('product-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final publicUrl = _client.storage.from('product-images').getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> delete(String publicUrl) async {
    final path = _storagePath(publicUrl);
    if (path == null) return;
    await _client.storage.from('product-images').remove([path]);
  }

  String? _storagePath(String? publicUrl) {
    if (publicUrl == null || publicUrl.isEmpty) return null;
    final uri = Uri.tryParse(publicUrl);
    if (uri == null) return null;
    const marker = '/product-images/';
    final index = uri.path.indexOf(marker);
    if (index < 0) return null;
    return Uri.decodeComponent(uri.path.substring(index + marker.length));
  }
}
