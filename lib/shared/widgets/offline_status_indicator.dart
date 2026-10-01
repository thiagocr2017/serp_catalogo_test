import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/services/offline_sync_service.dart';

class OfflineStatusIndicator extends ConsumerWidget {
  const OfflineStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncService = ref.watch(offlineSyncServiceProvider);
    final pendingCount = syncService.pendingCount;
    final isSyncing = syncService.isSyncing;

    if (pendingCount == 0 && !isSyncing) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSyncing ? Colors.blue : Colors.orange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            const Icon(Icons.cloud_off, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            isSyncing
                ? 'Sincronizando...'
                : '$pendingCount pendiente${pendingCount == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
