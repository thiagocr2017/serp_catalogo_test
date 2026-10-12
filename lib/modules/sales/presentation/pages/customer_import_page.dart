import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/customer_api.dart';
import '../../services/customer_import_service.dart';

class CustomerImportPage extends ConsumerStatefulWidget {
  const CustomerImportPage({super.key});

  @override
  ConsumerState<CustomerImportPage> createState() => _CustomerImportPageState();
}

class _CustomerImportPageState extends ConsumerState<CustomerImportPage> {
  CustomerImportPreview? _preview;
  CustomerImportResult? _result;
  String? _fileName;
  String? _loadError;
  bool _busy = false;

  CustomerImportService get _service =>
      CustomerImportService(ref.read(customerApiProvider));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver a clientes',
          onPressed: () => context.go('/sales/customers'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Importar clientes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Importación CSV',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Se crearán clientes nuevos. Los registros existentes no se modifican.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _saveTemplate,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Descargar plantilla'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _selectCsv,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Seleccionar CSV'),
              ),
              if (_fileName != null)
                Chip(
                  avatar: const Icon(Icons.description_outlined),
                  label: Text(_fileName!, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Columnas requeridas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'nombre_fiscal; nombre_fantasia; telefono; gira; direccion',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Columnas opcionales',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'correo; identificacion; tipo_cliente (CONTADO o CREDITO); dias_credito; '
                    'limite_credito; codigo_pais (CR por defecto); provincia; ciudad; categorias.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Separa varias categorías con |. El CSV puede usar ; o ,.',
                  ),
                ],
              ),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Procesando archivo...'),
          ],
          if (_loadError != null) ...[
            const SizedBox(height: 16),
            _MessagePanel(
              color: colors.errorContainer,
              textColor: colors.onErrorContainer,
              icon: Icons.error_outline,
              message: _loadError!,
            ),
          ],
          if (_preview case final preview?) ...[
            const SizedBox(height: 24),
            Semantics(
              liveRegion: true,
              label:
                  'Vista previa. ${preview.rows.length} filas válidas y ${preview.errors.length} errores.',
              child: _PreviewSection(preview: preview),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed:
                    _busy ||
                        preview.rows.isEmpty ||
                        preview.errors.isNotEmpty ||
                        _result != null
                    ? null
                    : _import,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text('Crear ${preview.rows.length} clientes'),
              ),
            ),
          ],
          if (_result case final result?) ...[
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              label:
                  'Importación terminada. ${result.created} clientes creados y ${result.errors.length} filas con error.',
              child: _MessagePanel(
                color: result.errors.isEmpty
                    ? colors.surfaceContainerHigh
                    : colors.errorContainer,
                textColor: result.errors.isEmpty
                    ? colors.onSurface
                    : colors.onErrorContainer,
                icon: result.errors.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
                message:
                    'Clientes creados: ${result.created}. Filas con error: ${result.errors.length}.',
              ),
            ),
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...result.errors.map(
                (error) => ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(error),
                  dense: true,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/sales/customers'),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Volver a clientes'),
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Importar otro archivo'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async {
    try {
      final location = await getSaveLocation(
        suggestedName: 'plantilla_clientes_serp.csv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Archivo CSV', extensions: ['csv']),
        ],
      );
      if (location == null) return;
      await File(location.path)
          .writeAsString(_service.templateCsv(), flush: true);
      if (mounted) _showMessage('Plantilla guardada.');
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = 'No se pudo guardar la plantilla: $error');
      }
    }
  }

  Future<void> _selectCsv() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Archivo CSV', extensions: ['csv']),
      ],
    );
    if (file == null || !mounted) return;
    setState(() {
      _busy = true;
      _loadError = null;
      _result = null;
    });
    try {
      final api = ref.read(customerApiProvider);
      final customers = await api.getCustomers();
      final categories = await api.getCustomerCategories();
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final preview = _service.parseCsv(
        text,
        existingCustomers: customers,
        categories: categories,
      );
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _preview = preview;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _loadError = 'No se pudo preparar la importación: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null || preview.rows.isEmpty || preview.errors.isNotEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _service.import(preview);
      ref.invalidate(customersProvider);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) {
        setState(
          () => _loadError = 'No se pudo completar la importación: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _preview = null;
      _result = null;
      _fileName = null;
      _loadError = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.preview});

  final CustomerImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revisión del archivo',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('Válidos: ${preview.rows.length}')),
            Chip(label: Text('Errores: ${preview.errors.length}')),
          ],
        ),
        if (preview.errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...preview.errors.map(
            (error) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.error_outline, color: colors.error),
              title: Text(error),
              dense: true,
            ),
          ),
        ],
        if (preview.rows.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...preview.rows
              .take(100)
              .map(
                (row) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(row.displayName),
                  subtitle: Text(
                    '${row.phone} · ${row.customerType == 'CREDIT' ? 'Crédito' : 'Contado'}',
                  ),
                  trailing: Text('Fila ${row.line}'),
                  dense: true,
                ),
              ),
          if (preview.rows.length > 100)
            Text(
              'Se muestran las primeras 100 filas de ${preview.rows.length}.',
            ),
        ],
      ],
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.message,
  });

  final Color color;
  final Color textColor;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: textColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: TextStyle(color: textColor)),
        ),
      ],
    ),
  );
}
