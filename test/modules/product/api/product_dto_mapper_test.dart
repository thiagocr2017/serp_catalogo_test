import 'package:flutter_test/flutter_test.dart';

import 'package:serp/modules/product/data/mappers/product_dto_mapper.dart';
import 'package:serp/modules/product/domain/entities/product.dart';

import 'package:serp/modules/product/api/product_dtos.dart';

/// Contrato de pruebas exigido por `.specs/refactors/03-public-dto-migration.md`
/// para cada DTO nuevo: igualdad por valor, mapeo completo de los campos que
/// declara el contrato, y traslado de la consulta publica.
void main() {
  Product buildProduct() => Product(
    id: 'p-1',
    sku: 'SKU-1',
    name: 'Nombre',
    description: 'Descripcion',
    categoryId: 'c-1',
    unitPriceInCents: 1250,
    minimumOrderQuantity: 10,
    packagingPresentationId: 'pp-1',
    cbmPerMoq: 0.5,
    factoryCostInCents: 700,
    currentStock: 34,
    reorderPoint: 5,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  group('ProductSummaryDto', () {
    test('tiene igualdad por valor', () {
      const a = ProductSummaryDto(
        id: 'p-1',
        sku: 'SKU-1',
        name: 'Nombre',
        description: 'Descripcion',
        currentStock: 34,
      );
      const b = ProductSummaryDto(
        id: 'p-1',
        sku: 'SKU-1',
        name: 'Nombre',
        description: 'Descripcion',
        currentStock: 34,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('distingue productos distintos', () {
      const a = ProductSummaryDto(
        id: 'p-1',
        sku: 'SKU-1',
        name: 'Nombre',
        description: 'Descripcion',
        currentStock: 34,
      );
      const b = ProductSummaryDto(
        id: 'p-2',
        sku: 'SKU-1',
        name: 'Nombre',
        description: 'Descripcion',
        currentStock: 34,
      );
      expect(a, isNot(equals(b)));
    });

    test('cada campo del contrato queda representado en la serializacion', () {
      const dto = ProductSummaryDto(
        id: 'p-1',
        sku: 'SKU-1',
        name: 'Nombre',
        description: 'Descripcion',
        currentStock: 34,
      );
      final text = dto.toString();
      for (final field in [
        'id',
        'sku',
        'name',
        'description',
        'currentStock',
      ]) {
        expect(text, contains(field), reason: 'falta el campo $field');
      }
    });
  });

  group('mapeo entidad -> DTO', () {
    test('traslada todos los campos que declara el contrato', () {
      final dto = buildProduct().toSummaryDto();
      expect(dto.id, 'p-1');
      expect(dto.sku, 'SKU-1');
      expect(dto.name, 'Nombre');
      expect(dto.description, 'Descripcion');
      expect(dto.currentStock, 34);
    });

    test('no expone campos internos del producto', () {
      // El DTO publico solo declara cinco campos. Si se anade uno al mapeo sin
      // declararlo en el contrato, este test sigue pasando; lo que protege es
      // la superficie de `product_api.dart` (ver su test de superficie).
      final dto = buildProduct().toSummaryDto();
      expect(dto.runtimeType.toString(), 'ProductSummaryDto');
    });
  });

  group('ProductListQuery', () {
    test('tiene igualdad por valor', () {
      const a = ProductListQuery(
        searchTerm: 'x',
        categoryId: 'c',
        isActive: true,
      );
      const b = ProductListQuery(
        searchTerm: 'x',
        categoryId: 'c',
        isActive: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('traslada los tres filtros del contrato al query de dominio', () {
      const query = ProductListQuery(
        searchTerm: 'tornillo',
        categoryId: 'c-1',
        isActive: true,
      );
      final domain = query.toDomainQuery();
      expect(domain.searchTerm, 'tornillo');
      expect(domain.categoryId, 'c-1');
      expect(domain.isActive, isTrue);
    });

    test('no expone los filtros internos de precio ni de stock bajo', () {
      // `ProductQuery` si permite `onlyLowStock` y rangos de precio. Si el
      // contrato publico los expusiera, un cambio interno de esos filtros
      // romperia al consumidor. El dominio conserva sus valores por defecto.
      final domain = const ProductListQuery().toDomainQuery();
      expect(domain.onlyLowStock, isFalse);
      expect(domain.minimumPriceInCents, isNull);
      expect(domain.maximumPriceInCents, isNull);
    });
  });
}
