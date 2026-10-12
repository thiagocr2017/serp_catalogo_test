import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serp/modules/product/domain/entities/product.dart';
import 'package:serp/modules/product/presentation/widgets/product_status_badge.dart';
import 'package:serp/shared/theme/app_theme.dart';

void main() {
  for (final (name, theme) in [
    ('claro', AppTheme.light),
    ('oscuro', AppTheme.dark),
  ]) {
    testWidgets('estado del producto es neutral en tema $name', (tester) async {
      for (final active in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: ProductStatusBadge(product: _product(isActive: active)),
            ),
          ),
        );

        final label = active ? 'Activo' : 'Inactivo';
        final expectedIcon = active
            ? Icons.check_circle_outline
            : Icons.visibility_off_outlined;
        final chip = tester.widget<Chip>(find.byType(Chip));
        final icon = chip.avatar! as Icon;
        final displayedLabel = active ? 'Activo · Disponible' : label;
        final text = tester.widget<Text>(find.text(displayedLabel));

        expect(icon.icon, expectedIcon);
        expect(icon.color, theme.colorScheme.onSurfaceVariant);
        expect(
          chip.backgroundColor,
          active
              ? theme.colorScheme.surfaceContainerHighest
              : Colors.transparent,
        );
        expect(chip.side?.color, theme.colorScheme.outlineVariant);
        expect(text.style?.color, theme.colorScheme.onSurfaceVariant);
      }
    });
  }
}

Product _product({required bool isActive}) => Product(
  id: 'product-id',
  sku: 'SKU-1',
  name: 'Producto',
  description: '',
  categoryId: 'category-id',
  unitPriceInCents: 1000,
  minimumOrderQuantity: 1,
  packagingPresentationId: 'presentation-id',
  cbmPerMoq: 0,
  factoryCostInCents: 500,
  currentStock: 5,
  reorderPoint: 1,
  isActive: isActive,
  createdAt: DateTime.utc(2026),
);
