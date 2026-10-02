import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:image/image.dart' as image;
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductImageService {
  const ProductImageService(this._client);
  final SupabaseClient _client;

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
    final decoded = image.decodeImage(await file.readAsBytes());
    if (decoded == null) {
      throw const FormatException('La imagen seleccionada no es válida.');
    }
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
    // aceptan extensiones jpg|jpeg|png|webp en minúsculas (.JPG → 403).
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
