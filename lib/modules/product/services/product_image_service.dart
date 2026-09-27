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

  Future<String> upload(String productId, Uint8List bytes) async {
    final path = '$productId.jpg';
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
    return _client.storage.from('product-images').getPublicUrl(path);
  }
}
