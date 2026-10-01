import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../configuration/configuration_module.dart';

import '../../di/product_providers.dart';
import '../../domain/entities/product_query.dart';
import '../../services/bulk_product_transfer_service.dart';
import '../controllers/product_list_controller.dart';

class ProductTransferPage extends ConsumerStatefulWidget {
  const ProductTransferPage({super.key});

  @override
  ConsumerState<ProductTransferPage> createState() =>
      _ProductTransferPageState();
}

class _ProductTransferPageState extends ConsumerState<ProductTransferPage> {
  BulkProductPreview? _preview;
  Map<String, Uint8List> _images = const {};
  String? _csvName;
  String? _zipName;
  bool _busy = false;

  BulkProductTransferService get _service => BulkProductTransferService(
    ref.read(productRepositoryProvider),
    ref.read(productImageServiceProvider),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importar / Exportar productos')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Gestión masiva de productos',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Usa un CSV compatible con Excel. Las imágenes se manejan en un ZIP y deben llamarse igual que el SKU, por ejemplo HJ300-1.JPG.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ActionCard(
                icon: Icons.description_outlined,
                title: '1. Descargar plantilla',
                description: 'Genera un CSV con todas las columnas admitidas para completarlo en Excel.',
                buttonText: 'Guardar plantilla CSV',
                onPressed: _busy ? null : _saveTemplate,
              ),
              _ActionCard(
                icon: Icons.file_download_outlined,
                title: 'Exportar productos',
                description: 'Descarga productos y categorías actuales en un CSV editable.',
                buttonText: 'Exportar CSV',
                onPressed: _busy ? null : _exportProducts,
              ),
              _ActionCard(
                icon: Icons.image_outlined,
                title: 'Exportar imágenes',
                description: 'Crea un ZIP con las imágenes disponibles nombradas por SKU.',
                buttonText: 'Exportar imágenes ZIP',
                onPressed: _busy ? null : _exportImages,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2. Preparar importación',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Primero selecciona el CSV. Opcionalmente agrega un ZIP de imágenes. El sistema valida todo antes de guardar.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _selectCsv,
                        icon: const Icon(Icons.upload_file),
                        label: Text(_csvName ?? 'Seleccionar CSV'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _selectImagesZip,
                        icon: const Icon(Icons.folder_zip_outlined),
                        label: Text(
                          _zipName ?? 'Agregar ZIP de imágenes (opcional)',
                        ),
                      ),
                      if (_preview != null)
                        FilledButton.icon(
                          onPressed:
                              _busy ||
                                  _preview!.rows.isEmpty ||
                                  _preview!.errors.isNotEmpty
                              ? null
                              : _import,
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Importar productos validados'),
                        ),
                    ],
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: 20),
                    _Preview(preview: _preview!, imageCount: _images.length),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Reglas importantes\n'
                '• El SKU identifica cada producto: si ya existe, se actualiza; si no existe, se crea.\n'
                '• La categoría debe existir previamente y escribirse exactamente como aparece en el sistema.\n'
                '• El stock_inicial solo se usa al crear productos nuevos. El stock existente cambia mediante movimientos de inventario.\n'
                '• Presentaciones aceptadas: UNIT/UNIDAD, BOX/CAJA y SET.\n'
                '• Excel debe guardar el archivo como CSV UTF-8 delimitado por punto y coma.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async => _saveText(
    suggestedName: 'plantilla_productos_serp.csv',
    content: _service.templateCsv(),
  );

  Future<void> _exportProducts() async {
    await _run(() async {
      final products = await ref.read(getProductsProvider)(
        const ProductQuery(),
      );
      final categories = await ref.read(categoriesProvider.future);
      await _saveText(
        suggestedName: 'productos_serp.csv',
        content: _service.exportCsv(products, categories),
      );
    });
  }

  Future<void> _exportImages() async {
    await _run(() async {
      final products = await ref.read(getProductsProvider)(
        const ProductQuery(),
      );
      final location = await getSaveLocation(
        suggestedName: 'imagenes_productos_serp.zip',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Archivo ZIP', extensions: ['zip']),
        ],
      );
      if (location == null) return;
      final bytes = await _service.exportImagesZip(products);
      await File(location.path).writeAsBytes(bytes, flush: true);
      _notify('ZIP exportado correctamente.');
    });
  }

  Future<void> _selectCsv() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV compatible con Excel', extensions: ['csv']),
      ],
    );
    if (file == null) return;
    await _run(() async {
      final categories = await ref.read(categoriesProvider.future);
      final existing = await ref.read(getProductsProvider)(
        const ProductQuery(),
      );
      final presentations = await ref.read(
        packagingPresentationDtosProvider.future,
      );
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      setState(() {
        _csvName = file.name;
        _preview = _service.parseCsv(
          text,
          categories: categories,
          existingProducts: existing,
          presentations: presentations,
        );
      });
    });
  }

  Future<void> _selectImagesZip() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Imágenes comprimidas', extensions: ['zip']),
      ],
    );
    if (file == null) return;
    await _run(() async {
      final images = _service.readImageZip(await file.readAsBytes());
      setState(() {
        _zipName = file.name;
        _images = images;
      });
      _notify('${images.length} imagen(es) reconocida(s).');
    });
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null) return;
    await _run(() async {
      final result = await _service.import(preview, images: _images);
      ref.invalidate(productListControllerProvider);
      ref.invalidate(categoriesProvider);
      if (!mounted) return;
      setState(() {
        _preview = null;
        _csvName = null;
        _zipName = null;
        _images = const {};
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Importación finalizada'),
          content: Text(
            'Creados: ${result.created}\nActualizados: ${result.updated}\nErrores: ${result.errors.length}'
            '${result.errors.isEmpty ? '' : '\n\n${result.errors.take(8).join('\n')}'}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _saveText({
    required String suggestedName,
    required String content,
  }) async {
    await _run(() async {
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV compatible con Excel', extensions: ['csv']),
        ],
      );
      if (location == null) return;
      await File(location.path).writeAsString(content, flush: true);
      _notify('Archivo guardado correctamente.');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _notify('No fue posible completar la operación: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });
  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 330,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(buttonText)),
          ],
        ),
      ),
    ),
  );
}

class _Preview extends StatelessWidget {
  const _Preview({required this.preview, required this.imageCount});
  final BulkProductPreview preview;
  final int imageCount;

  @override
  Widget build(BuildContext context) {
    final creates = preview.rows.where((row) => row.existing == null).length;
    final updates = preview.rows.length - creates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          children: [
            Chip(label: Text('$creates nuevo(s)')),
            Chip(label: Text('$updates actualización(es)')),
            Chip(label: Text('$imageCount imagen(es) en ZIP')),
            Chip(label: Text('${preview.errors.length} error(es)')),
          ],
        ),
        if (preview.errors.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Text(preview.errors.take(12).join('\n')),
          ),
        if (preview.rows.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Fila')),
                  DataColumn(label: Text('Acción')),
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('Producto')),
                  DataColumn(label: Text('Precio')),
                ],
                rows: [
                  for (final row in preview.rows)
                    DataRow(
                      cells: [
                        DataCell(Text('${row.line}')),
                        DataCell(
                          Text(row.existing == null ? 'Crear' : 'Actualizar'),
                        ),
                        DataCell(Text(row.sku)),
                        DataCell(Text(row.name)),
                        DataCell(
                          Text(
                            'USD ${(row.unitPriceInCents / 100).toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
