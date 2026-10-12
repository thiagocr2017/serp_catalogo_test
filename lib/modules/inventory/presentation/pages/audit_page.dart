import 'dart:async';

import 'package:flutter/material.dart';

import 'package:serp/modules/inventory/api/inventory_dtos.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../di/inventory_providers.dart';
import '../../../../shared/utilities/search_query.dart';

class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  final _search = TextEditingController();
  String _query = '';
  DateTime? _from;
  DateTime? _to;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(auditEntriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría'),
        actions: [
          IconButton(
            tooltip: 'Actualizar auditoría',
            onPressed: () => ref.invalidate(auditEntriesProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined),
              const SizedBox(height: 12),
              const Text('No fue posible cargar la auditoría.'),
              const SizedBox(height: 4),
              Text(
                error is TimeoutException
                    ? 'La consulta tardó demasiado. Revisa la conexión e inténtalo de nuevo.'
                    : error.toString(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(auditEntriesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (items) {
          final query = _query.trim().toLowerCase();
          final events = _group(items).where((event) {
            final localDate = event.createdAt.toLocal();
            final afterFrom =
                _from == null ||
                !localDate.isBefore(
                  DateTime(_from!.year, _from!.month, _from!.day),
                );
            final beforeTo =
                _to == null ||
                localDate.isBefore(
                  DateTime(_to!.year, _to!.month, _to!.day + 1),
                );
            if (!afterFrom || !beforeTo) return false;
            if (query.isEmpty) return true;
            return event.searchable.contains(query);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (value) =>
                      setState(() => _query = effectiveSearchQuery(value)),
                  decoration: InputDecoration(
                    labelText: 'Buscar en auditoría',
                    hintText:
                        'Tabla, operación, campo, valor, usuario o equipo',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: true),
                      icon: const Icon(Icons.date_range),
                      label: Text(_from == null ? 'Desde' : _dateLabel(_from!)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: false),
                      icon: const Icon(Icons.event),
                      label: Text(_to == null ? 'Hasta' : _dateLabel(_to!)),
                    ),
                    if (_from != null || _to != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _from = null;
                          _to = null;
                        }),
                        child: const Text('Limpiar fechas'),
                      ),
                    const Spacer(),
                    Text('${events.length} acción(es)'),
                  ],
                ),
              ),
              Expanded(
                child: events.isEmpty
                    ? const Center(
                        child: Text('No hay resultados para esta búsqueda.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: events.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) {
                          final event = events[i];
                          return ExpansionTile(
                            leading: Icon(_eventIcon(event)),
                            title: Text(_eventTitle(event)),
                            subtitle: Text(
                              '${event.actorName ?? 'Sistema'} · '
                              '${event.deviceName ?? 'Sin dispositivo'}\n'
                              '${_dateTimeLabel(event.createdAt.toLocal())}',
                            ),
                            trailing: event.resourcePath == null
                                ? const Icon(Icons.expand_more)
                                : IconButton(
                                    tooltip: 'Abrir elemento afectado',
                                    onPressed: () =>
                                        context.go(event.resourcePath!),
                                    icon: const Icon(Icons.open_in_new),
                                  ),
                            children: [
                              for (final detail in event.changes)
                                ListTile(
                                  dense: true,
                                  title: Text(_fieldLabel(detail.fieldName)),
                                  subtitle: Text(
                                    '${detail.oldValue ?? '∅'} → ${detail.newValue ?? '∅'}',
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
    );
    if (selected != null) {
      setState(() => isFrom ? _from = selected : _to = selected);
    }
  }

  List<_AuditEvent> _group(List<AuditEntryDto> items) {
    final groups = <String, List<AuditEntryDto>>{};
    for (final item in items) {
      final second = item.createdAt.millisecondsSinceEpoch ~/ 1000;
      final key = '${item.tableName}|${item.recordId}|$second';
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups.values.map(_AuditEvent.new).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String _eventTitle(_AuditEvent event) {
    final resource = _tableLabel(event.tableName);
    final label = event.resourceLabel?.trim();
    final action = switch (event.operation) {
      'INSERT' => 'Se creó',
      'SOFT_DELETE' => 'Se desactivó',
      _
          when event.details.any(
            (detail) =>
                detail.fieldName == 'is_active' && detail.newValue == 'true',
          ) =>
        'Se reactivó',
      _ => 'Se actualizó',
    };
    return '$action $resource${label?.isNotEmpty == true ? ' ${label!}' : ''}';
  }

  IconData _eventIcon(_AuditEvent event) => switch (event.operation) {
    'INSERT' => Icons.add_circle_outline,
    'SOFT_DELETE' => Icons.remove_circle_outline,
    _ => Icons.edit_outlined,
  };

  String _tableLabel(String table) => switch (table) {
    'products' => 'un producto',
    'categories' => 'una categoría',
    'bulk_promotions' => 'una promoción',
    _ => table,
  };

  String _fieldLabel(String field) => switch (field) {
    'name' => 'Nombre',
    'sku' => 'Código del producto',
    'description' => 'Descripción',
    'category_id' => 'Categoría',
    'unit_price' => 'Precio unitario',
    'current_stock' => 'Stock',
    'is_active' => 'Estado activo',
    'image_url' => 'Imagen',
    'packaging_type' => 'Presentación',
    'minimum_sale_quantity' => 'Venta mínima',
    'min_order_quantity' => 'MOQ de recompra',
    'factory_cost' => 'Costo de fábrica',
    'currency_code' => 'Moneda',
    'cbm_per_moq' => 'CBM por MOQ',
    'reorder_point' => 'Punto de reorden',
    'promo_price' => 'Precio promocional',
    'promo_text' => 'Texto de promoción',
    'image_position_x' => 'Posición horizontal de imagen',
    'image_position_y' => 'Posición vertical de imagen',
    _ => field.replaceAll('_', ' '),
  };

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _dateTimeLabel(DateTime value) =>
      '${_dateLabel(value)} ${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _AuditEvent {
  _AuditEvent(this.details);

  final List<AuditEntryDto> details;
  static const _technicalFields = {
    'id',
    'created_at',
    'updated_at',
    'deleted_at',
    'created_by',
    'updated_by',
    'deleted_by',
    'created_device_name',
    'created_device_identifier',
    'updated_device_name',
    'updated_device_identifier',
  };
  AuditEntryDto get first => details.first;
  String get tableName => first.tableName;
  String get operation => details.any((detail) => detail.operation == 'INSERT')
      ? 'INSERT'
      : details.any((detail) => detail.operation == 'SOFT_DELETE')
      ? 'SOFT_DELETE'
      : 'UPDATE';
  String? get actorName => first.actorName;
  String? get deviceName => first.deviceName;
  String? get resourceLabel => first.resourceLabel;
  String? get resourcePath => first.resourcePath;
  DateTime get createdAt => first.createdAt;
  List<_AuditChange> get changes {
    final grouped = <String, List<AuditEntryDto>>{};
    for (final detail in details) {
      if (_technicalFields.contains(detail.fieldName)) continue;
      grouped.putIfAbsent(detail.fieldName, () => []).add(detail);
    }
    return [
      for (final entry in grouped.entries)
        _AuditChange(
          fieldName: entry.key,
          oldValue: entry.value.any((detail) => detail.oldValue == null)
              ? null
              : entry.value.first.oldValue,
          newValue: _finalValue(entry.value),
        ),
    ];
  }

  static String? _finalValue(List<AuditEntryDto> details) {
    final intermediateValues = details
        .map((detail) => detail.oldValue)
        .whereType<String>()
        .toSet();
    for (final detail in details) {
      if (detail.newValue != null &&
          !intermediateValues.contains(detail.newValue)) {
        return detail.newValue;
      }
    }
    return details.first.newValue;
  }

  String get searchable => [
    tableName,
    first.recordId,
    operation,
    resourceLabel,
    actorName,
    deviceName,
    for (final detail in details) ...[
      detail.fieldName,
      detail.oldValue,
      detail.newValue,
    ],
  ].whereType<String>().join(' ').toLowerCase();
}

class _AuditChange {
  const _AuditChange({
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
  });

  final String fieldName;
  final String? oldValue;
  final String? newValue;
}
