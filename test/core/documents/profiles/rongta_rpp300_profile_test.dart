import 'package:flutter_test/flutter_test.dart';
import 'package:serp/core/documents/documents.dart';

void main() {
  group('RongtaRpp300Profile', () {
    const profile = RongtaRpp300Profile();

    test('cumple especificaciones del perfil térmico estándar', () {
      expect(profile.name, 'Rongta RPP300');
      expect(profile.paperWidthMm, 80.0);
      expect(profile.printableWidthMm, 72.0);
      expect(profile.dpi, 203);
      expect(profile.dotsPerLine, 576);
      expect(profile.charactersPerLineFontA, 48);
      expect(profile.charactersPerLineFontB, 64);
      expect(profile.supportsCut, isFalse);
      expect(profile.supportsQr, isTrue);
      expect(profile.supportsImages, isTrue);
      expect(profile.supportsCashDrawer, isFalse);
      expect(profile.defaultFeedLines, 4);
      expect(profile.codePageNumber, 2); // CP850 Multilingual
    });
  });
}
