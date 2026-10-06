import 'package:flutter/material.dart';

import '../theme/semantic_colors.dart';

/// Tono semántico para indicadores de estado (chips, avatares, badges).
enum StatusTone { success, danger, info, warning, neutral }

/// Resuelve el par (fondo, texto) de [tone] adaptado al brillo del tema,
/// preservando el contraste en modo claro y modo oscuro.
(Color background, Color foreground) resolveStatusColors(
  BuildContext context,
  StatusTone tone,
) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  final scheme = theme.colorScheme;
  final semantic =
      theme.extension<AppSemanticColors>() ??
      (dark ? AppSemanticColors.dark : AppSemanticColors.light);
  return switch (tone) {
    StatusTone.success => (
      semantic.successBackground,
      semantic.successForeground,
    ),
    StatusTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
    StatusTone.info => (semantic.infoBackground, semantic.infoForeground),
    StatusTone.warning => (
      semantic.warningBackground,
      semantic.warningForeground,
    ),
    StatusTone.neutral => (
      scheme.surfaceContainerHighest,
      scheme.onSurfaceVariant,
    ),
  };
}

/// Chip de estado con colores semánticos consistentes en ambos temas.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.tooltip,
  });

  final String label;
  final StatusTone tone;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = resolveStatusColors(context, tone);
    final chip = Chip(
      label: Text(label, style: TextStyle(color: foreground)),
      backgroundColor: background,
      side: BorderSide(color: foreground.withValues(alpha: .45)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (tooltip == null) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}
