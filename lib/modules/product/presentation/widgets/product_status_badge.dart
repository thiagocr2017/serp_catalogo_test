import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';

class ProductStatusBadge extends StatelessWidget {
  const ProductStatusBadge({
    super.key,
    required this.product,
    this.showStockStatus = true,
  });

  final Product product;
  final bool showStockStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = product.isActive;
    final stockStatus = product.isOutOfStock
        ? 'Agotado'
        : product.requiresRestock
        ? 'Stock bajo'
        : 'Disponible';
    return Chip(
      avatar: Icon(
        active ? Icons.check_circle_outline : Icons.visibility_off_outlined,
        size: 18,
        color: scheme.onSurfaceVariant,
      ),
      label: Text(
        active
            ? showStockStatus
                  ? 'Activo · $stockStatus'
                  : 'Activo'
            : 'Inactivo',
        style: TextStyle(color: scheme.onSurfaceVariant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: active
          ? scheme.surfaceContainerHighest
          : Colors.transparent,
      side: BorderSide(color: scheme.outlineVariant),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
