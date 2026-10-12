import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';
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

  static image.Image _decoded(Uint8List bytes) {
    try {
      final decoded = image.decodeImage(bytes);
      if (decoded != null) return decoded;
    } catch (_) {}
    throw const FormatException('La imagen seleccionada no es válida.');
  }

  static ({int width, int height}) dimensionsOf(Uint8List bytes) {
    final decoded = _decoded(bytes);
    return (width: decoded.width, height: decoded.height);
  }

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

    // Invalidate local cache
    await _clearThumbnail(sku);

    final publicUrl = _client.storage.from('product-images').getPublicUrl(path);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> delete(String publicUrl) async {
    final path = _storagePath(publicUrl);
    if (path == null) return;
    await _client.storage.from('product-images').remove([path]);

    // Attempt to extract SKU from path
    final match = RegExp(r'^([A-Za-z0-9._]+)-').firstMatch(path);
    if (match != null) {
      await _clearThumbnail(match.group(1)!);
    }
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

  // --- THUMBNAILS (LOCAL-FIRST CACHE) ---

  Future<File> getLocalThumbnail(String sku, String publicUrl) async {
    final safeSku = sku
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final supportDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${supportDir.path}/cache/products');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);

    final thumbFile = File('${cacheDir.path}/${safeSku}_thumb.jpg');
    final sourceFile = File('${cacheDir.path}/${safeSku}_thumb.source');

    if (await thumbFile.exists() && await sourceFile.exists()) {
      final cachedSource = await sourceFile.readAsString();
      if (cachedSource == publicUrl) return thumbFile;
    }

    if (await thumbFile.exists()) {
      await thumbFile.delete();
      PaintingBinding.instance.imageCache.evict(FileImage(thumbFile));
    }

    // The URL carries a version when an image is replaced, so only changed
    // sources need a fresh download and thumbnail.
    final bytes = await loadExisting(publicUrl);
    final decoded = image.decodeImage(bytes);
    if (decoded != null) {
      final thumbnail = image.copyResizeCropSquare(decoded, size: 256);
      final thumbBytes = Uint8List.fromList(
        image.encodeJpg(thumbnail, quality: 80),
      );
      await thumbFile.writeAsBytes(thumbBytes);
    } else {
      await thumbFile.writeAsBytes(bytes);
    }
    await sourceFile.writeAsString(publicUrl, flush: true);

    return thumbFile;
  }

  Future<void> _clearThumbnail(String sku) async {
    final safeSku = sku
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final supportDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${supportDir.path}/cache/products');
    final thumbFile = File('${cacheDir.path}/${safeSku}_thumb.jpg');
    final sourceFile = File('${cacheDir.path}/${safeSku}_thumb.source');
    if (await thumbFile.exists()) {
      await thumbFile.delete();
      PaintingBinding.instance.imageCache.evict(FileImage(thumbFile));
    }
    if (await sourceFile.exists()) await sourceFile.delete();
  }
}
