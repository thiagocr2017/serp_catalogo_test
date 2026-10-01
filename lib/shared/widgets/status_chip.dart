import 'package:flutter/material.dart';

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
  return switch (tone) {
    StatusTone.success =>
      dark
          ? (
              Colors.green.shade900.withValues(alpha: .35),
              Colors.green.shade200,
            )
          : (Colors.green.shade100, Colors.green.shade900),
    StatusTone.danger =>
      dark
          ? (Colors.red.shade900.withValues(alpha: .35), Colors.red.shade200)
          : (Colors.red.shade100, Colors.red.shade900),
    StatusTone.info =>
      dark
          ? (Colors.blue.shade900.withValues(alpha: .35), Colors.blue.shade200)
          : (Colors.blue.shade100, Colors.blue.shade900),
    StatusTone.warning =>
      dark
          ? (
              Colors.orange.shade900.withValues(alpha: .35),
              Colors.orange.shade200,
            )
          : (Colors.orange.shade100, Colors.orange.shade900),
    StatusTone.neutral =>
      dark
          ? (scheme.surfaceContainerHighest, scheme.onSurfaceVariant)
          : (Colors.grey.shade200, Colors.grey.shade800),
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
