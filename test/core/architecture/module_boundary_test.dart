import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Prueba de frontera exigida por `MODULE_SECURITY_CONTRACT.md` §2 y §10 y por
/// `.specs/refactors/03-public-dto-migration.md` T8.
///
/// Ningun modulo de negocio puede importar ni exportar `data/`, `domain/`,
/// `di/`, `presentation/` ni `services/` de **otro** modulo. La unica
/// superficie es `<name>_module.dart`, que solo expone `api/`. `main.dart` esta
/// autorizado como raiz de composicion.
const _internalLayers = ['data/', 'domain/', 'di/', 'presentation/', 'services/'];

void main() {
  test('ningun modulo importa capas internas de otro modulo', () {
    final violations = <String>[];

    for (final file in _dartFilesUnder('lib')) {
      if (file.path == 'lib/main.dart') continue; // raiz de composicion

      final owner = _moduleOwnerOf(file.path);
      if (owner == null) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final uri = _importUriOf(lines[i]);
        if (uri == null) continue;

        final target = _resolve(file.path, uri);
        if (target == null) continue;

        final targetOwner = _moduleOwnerOf(target);
        if (targetOwner == null || targetOwner == owner) continue;
        if (!_isInternalLayer(target)) continue;

        violations.add('${file.path}:${i + 1} -> $target');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Imports cruzados de capas internas:\n${violations.join('\n')}',
    );
  });

  test('api/ e <module>_module.dart solo exponen contrato, no implementacion', () {
    final violations = <String>[];

    for (final file in _dartFilesUnder('lib')) {
      final isModuleIndex = file.path.endsWith('_module.dart');
      final isApiSurface = RegExp(r'^lib/modules/[a-z_]+/api/').hasMatch(file.path);
      if (!isModuleIndex && !isApiSurface) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final uri = _exportUriOf(lines[i]);
        if (uri == null) continue;

        final target = _resolve(file.path, uri);
        if (target == null) continue;
        if (!_isForbiddenFromPublicSurface(target)) continue;

        violations.add('${file.path}:${i + 1} -> $target');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Superficie publica que expone implementacion interna '
          '(MODULE_SECURITY_CONTRACT.md §3):\n${violations.join('\n')}',
    );
  });
}

Iterable<File> _dartFilesUnder(String dir) sync* {
  for (final entity in Directory(dir).listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

/// Nombre del modulo propietario de una ruta bajo `lib/modules/`, o `null`.
String? _moduleOwnerOf(String path) =>
    RegExp(r'^lib/modules/([a-z_]+)/').firstMatch(path)?.group(1);

/// `lib/modules/product/di/x.dart` -> `di/x.dart`
bool _isInternalLayer(String path) {
  final rest = RegExp(r'^lib/modules/[a-z_]+/(.*)$').firstMatch(path)?.group(1);
  if (rest == null) return false;
  return _internalLayers.any(rest.startsWith);
}

/// Lo que una superficie publica (`api/` o `<module>_module.dart`) jamas puede
/// exportar.
///
/// `domain/entities/` **tambien** deberia estar prohibido por
/// `MODULE_SECURITY_CONTRACT.md` §3 («entidades internas con campos que el
/// consumidor no necesita»), pero todavia se expone en `product`, `inventory`
/// y `sales`. Quitarlo es T5 y T7 de
/// `.specs/refactors/03-public-dto-migration.md`; cuando se completen, hay que
/// ampliar esta lista y comprobar que el test sigue pasando.
const _forbiddenFromPublicSurface = [
  'data/',
  'di/',
  'presentation/',
  'services/',
  'domain/repositories/',
  'domain/use_cases/',
];

bool _isForbiddenFromPublicSurface(String path) {
  final rest = RegExp(r'^lib/modules/[a-z_]+/(.*)$').firstMatch(path)?.group(1);
  if (rest == null) return false;
  return _forbiddenFromPublicSurface.any(rest.startsWith);
}

String? _importUriOf(String line) => _uriOf(line, 'import');
String? _exportUriOf(String line) => _uriOf(line, 'export');

String? _uriOf(String line, String keyword) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('$keyword ')) return null;
  return RegExp("^$keyword '([^']+)'").firstMatch(trimmed)?.group(1);
}

/// Resuelve un `import`/`export` a una ruta bajo `lib/`.
///
/// `package:serp/modules/sales/x.dart` vive en `lib/modules/sales/x.dart`.
/// Cualquier otro esquema se descarta; el resto se resuelve relativo al
/// archivo que lo declara, igual que hace Dart. Ojo: `'di/x.dart'` tambien es
/// relativo, aunque no empiece por `./`.
String? _resolve(String fromFile, String uri) {
  if (uri.startsWith('package:serp/')) {
    return 'lib/${uri.substring('package:serp/'.length)}';
  }
  if (uri.startsWith('dart:') || uri.startsWith('package:')) return null;

  final parts = fromFile.split('/')..removeLast();
  for (final segment in uri.split('/')) {
    if (segment == '.' || segment.isEmpty) continue;
    if (segment == '..') {
      if (parts.isEmpty) return null;
      parts.removeLast();
      continue;
    }
    parts.add(segment);
  }
  return parts.join('/');
}
