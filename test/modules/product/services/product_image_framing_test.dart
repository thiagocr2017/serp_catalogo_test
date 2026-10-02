import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:serp/modules/product/services/product_image_service.dart';

Uint8List testJpg(int width, int height) {
  final picture = image.Image(width: width, height: height);
  image.fill(picture, color: image.ColorRgb8(200, 50, 50));
  return Uint8List.fromList(image.encodeJpg(picture));
}

({int width, int height}) decodedSize(Uint8List bytes) {
  final decoded = image.decodeImage(bytes)!;
  return (width: decoded.width, height: decoded.height);
}

void main() {
  test('dimensionsOf reports the real size', () {
    expect(
      ProductImageService.dimensionsOf(testJpg(300, 200)),
      (width: 300, height: 200),
    );
  });

  test('zoom 1 keeps the full image', () {
    final framed = ProductImageService.applyFraming(
      testJpg(300, 200),
      focalX: 0.5,
      focalY: 0.5,
      zoom: 1,
    );
    expect(decodedSize(framed), (width: 300, height: 200));
  });

  test('zoom 2 halves each side around the focal point', () {
    final framed = ProductImageService.applyFraming(
      testJpg(300, 200),
      focalX: 0.5,
      focalY: 0.5,
      zoom: 2,
    );
    expect(decodedSize(framed), (width: 150, height: 100));
  });

  test('focal corners clamp inside the image', () {
    expect(
      ProductImageService.cropWindow(
        300,
        200,
        focalX: 0,
        focalY: 0,
        zoom: 2,
      ),
      (x: 0, y: 0, width: 150, height: 100),
    );
    expect(
      ProductImageService.cropWindow(
        300,
        200,
        focalX: 1,
        focalY: 1,
        zoom: 2,
      ),
      (x: 150, y: 100, width: 150, height: 100),
    );
  });

  test('invalid bytes throw a FormatException', () {
    expect(
      () => ProductImageService.applyFraming(
        Uint8List.fromList([0, 1, 2, 3]),
        focalX: 0.5,
        focalY: 0.5,
        zoom: 1,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
