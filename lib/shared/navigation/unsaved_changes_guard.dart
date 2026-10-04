import 'package:flutter/material.dart';

class UnsavedChangesGuard {
  UnsavedChangesGuard._();

  static final instance = UnsavedChangesGuard._();

  final hasUnsavedChanges = ValueNotifier<bool>(false);

  void markDirty() => hasUnsavedChanges.value = true;

  void markClean() => hasUnsavedChanges.value = false;

  Future<bool> confirmDiscard(
    BuildContext context, {
    bool hasUnsavedChanges = true,
  }) async {
    if (!hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir sin guardar'),
        content: const Text(
          'Tienes cambios sin guardar. Si sales ahora se perderán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<bool> confirmNavigation(BuildContext context) async {
    if (!hasUnsavedChanges.value) return true;
    final discard = await confirmDiscard(context);
    if (discard == true) {
      markClean();
      return true;
    }
    return false;
  }
}
