import 'package:flutter/material.dart';

class ListKpi {
  const ListKpi({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;
}

class ListKpiStrip extends StatelessWidget {
  const ListKpiStrip({required this.items, super.key});

  final List<ListKpi> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            constraints: const BoxConstraints(minWidth: 132),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.value.toString(),
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(item.label, style: theme.textTheme.labelMedium),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
