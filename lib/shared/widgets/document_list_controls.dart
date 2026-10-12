import 'package:flutter/material.dart';

import '../utilities/search_query.dart';
import 'list_kpi_strip.dart';

class DocumentListControls extends StatelessWidget {
  const DocumentListControls({
    required this.searchController,
    required this.searchLabel,
    required this.searchHint,
    required this.onSearchChanged,
    required this.statusValue,
    required this.statusOptions,
    required this.onStatusChanged,
    required this.kpis,
    required this.resultCount,
    required this.totalCount,
    required this.onClear,
    super.key,
  });

  final TextEditingController searchController;
  final String searchLabel;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final String statusValue;
  final List<({String value, String label})> statusOptions;
  final ValueChanged<String> onStatusChanged;
  final List<ListKpi> kpis;
  final int resultCount;
  final int totalCount;
  final VoidCallback onClear;

  bool get _hasFilters =>
      effectiveSearchQuery(searchController.text).isNotEmpty ||
      statusValue != 'ALL';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ListKpiStrip(items: kpis),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 380,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                labelText: searchLabel,
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String>(
              initialValue: statusValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final option in statusOptions)
                  DropdownMenuItem(
                    value: option.value,
                    child: Text(option.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onStatusChanged(value);
              },
            ),
          ),
          Text('Mostrando $resultCount de $totalCount'),
          if (_hasFilters)
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpiar filtros'),
            ),
        ],
      ),
    ],
  );
}
