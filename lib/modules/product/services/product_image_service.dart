import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as image;
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) {
    final z = zoom.clamp(1, 3).toDouble();
    final width = (imageWidth / z).round().clamp(1, imageWidth);
    final height = (imageHeight / z).round().clamp(1, imageHeight);
    final x = (focalX * imageWidth - width / 2)
        .round()
        .clamp(0, imageWidth - width);
    final y = (focalY * imageHeight - height / 2)
        .round()
        .clamp(0, imageHeight - height);
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
  }) {
    final decoded = _decoded(bytes);
    final window = cropWindow(
      decoded.width,
      decoded.height,
      focalX: focalX,
      focalY: focalY,
      zoom: zoom,
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
    String? previousUrl,
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
    // Minúsculas obligatorias: las políticas RLS de product-images solo
    // aceptan extensiones jpg|jpeg|png|webp en minúsculas (una extensión
    // en mayúsculas devuelve 403).
    final path = '$safeSku.jpg';
    final previousPath = _storagePath(previousUrl);
    if (previousPath != null) {
      await _client.storage.from('product-images').remove([previousPath]);
    }
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
