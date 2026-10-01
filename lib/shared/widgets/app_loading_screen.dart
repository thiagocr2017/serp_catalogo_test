import 'package:flutter/material.dart';

class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key, this.message = 'Iniciando SERP...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3949AB),
      brightness: Brightness.dark,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SERP',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sistema de Gestión Comercial',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.circular(4),
                minHeight: 4,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
