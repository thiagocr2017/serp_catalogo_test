import 'package:flutter/material.dart';

import 'semantic_colors.dart';

enum AppActionIntent { primary, secondary, success, warning, danger }

/// Boton compartido para acciones cuya intencion visual debe ser explicita.
class IntentButton extends StatelessWidget {
  const IntentButton({
    required this.intent,
    required this.onPressed,
    required this.label,
    this.icon,
    super.key,
  });

  final AppActionIntent intent;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic =
        Theme.of(context).extension<AppSemanticColors>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppSemanticColors.dark
            : AppSemanticColors.light);
    final filled =
        intent == AppActionIntent.primary ||
        intent == AppActionIntent.success ||
        intent == AppActionIntent.warning ||
        intent == AppActionIntent.danger;
    final background = switch (intent) {
      AppActionIntent.success => semantic.successBackground,
      AppActionIntent.warning => semantic.warningBackground,
      AppActionIntent.danger => colors.error,
      _ => null,
    };
    final foreground = switch (intent) {
      AppActionIntent.success => semantic.successForeground,
      AppActionIntent.warning => semantic.warningForeground,
      AppActionIntent.danger => colors.onError,
      _ => null,
    };
    final style = ButtonStyle(
      backgroundColor: background == null
          ? null
          : WidgetStatePropertyAll(background),
      foregroundColor: foreground == null
          ? null
          : WidgetStatePropertyAll(foreground),
    );

    if (filled) {
      return icon == null
          ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon),
              label: Text(label),
            );
    }
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon),
            label: Text(label),
          );
  }
}
