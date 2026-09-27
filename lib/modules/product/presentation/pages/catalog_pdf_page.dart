import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../core/configuration/settings_providers.dart';
import '../../di/product_providers.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';
import '../../services/catalog_pdf_service.dart';

class CatalogPdfPage extends ConsumerStatefulWidget {
  const CatalogPdfPage({super.key});
  @override
  ConsumerState<CatalogPdfPage> createState() => _CatalogPdfPageState();
}

class _CatalogPdfPageState extends ConsumerState<CatalogPdfPage> {
  final agent = TextEditingController(text: 'Thiago Lopez');
  final phone = TextEditingController(text: '+506');
  String companyName = '';
  String paymentMethods = '';
  String backgroundColor = '#FFFFFF';
  String cardColor = '#FFFFFF';
  String accentColor = '#3949AB';
  String textColor = '#111111';
  int cards = 4;
  List<Product>? products;
  Map<String, String> categoryNames = const {};
  Uint8List? logoBytes;
  final selected = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ref.read(getProductsProvider)(
      const ProductQuery(isActive: true),
    );
    final categories = await ref.read(categoriesProvider.future);
    final settings = await ref.read(businessSettingsProvider.future);
    if (mounted) {
      final sharedSelection = ref.read(selectedProductIdsProvider);
      setState(() {
        products = data;
        categoryNames = {
          for (final category in categories) category.id: category.name,
        };
        companyName = settings.companyName;
        paymentMethods = settings.paymentMethods;
        selected.addAll(
          sharedSelection.isEmpty
              ? data.map((p) => p.id)
              : data
                    .where((p) => sharedSelection.contains(p.id))
                    .map((p) => p.id),
        );
      });
    }
  }

  @override
  void dispose() {
    agent.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = products;
    return Scaffold(
      appBar: AppBar(title: const Text('Generar catálogo PDF')),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                SizedBox(
                  width: 360,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Datos de empresa',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => context.go('/settings'),
                        title: Text(companyName),
                        subtitle: Text(
                          paymentMethods.isEmpty
                              ? 'Sin métodos de pago configurados'
                              : paymentMethods,
                        ),
                        trailing: const Icon(Icons.settings_outlined),
                      ),
                      const Text(
                        'Estos datos se administran en Configuración y se usan automáticamente.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final file = await openFile(
                            acceptedTypeGroups: const [
                              XTypeGroup(
                                label: 'Imágenes',
                                extensions: ['png', 'jpg', 'jpeg'],
                              ),
                            ],
                          );
                          if (file != null) {
                            final bytes = await file.readAsBytes();
                            if (mounted) setState(() => logoBytes = bytes);
                          }
                        },
                        icon: const Icon(Icons.business),
                        label: Text(
                          logoBytes == null ? 'Seleccionar logo' : 'Logo listo',
                        ),
                      ),
                      const Divider(height: 28),
                      Text(
                        'Datos del catálogo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextField(
                        controller: agent,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Agente'),
                      ),
                      TextField(
                        controller: phone,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp',
                        ),
                      ),
                      const Divider(height: 28),
                      Text(
                        'Colores de la plantilla',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      _colorField(
                        'Fondo',
                        backgroundColor,
                        (value) => setState(() => backgroundColor = value),
                      ),
                      _colorField(
                        'Tarjetas',
                        cardColor,
                        (value) => setState(() => cardColor = value),
                      ),
                      _colorField(
                        'Destaque',
                        accentColor,
                        (value) => setState(() => accentColor = value),
                      ),
                      _colorField(
                        'Fuente',
                        textColor,
                        (value) => setState(() => textColor = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: cards,
                        decoration: const InputDecoration(
                          labelText: 'Tarjetas por página',
                        ),
                        items: const [0, 1, 2, 3, 4, 6]
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                  v == 0 ? 'Lista compacta' : '$v tarjetas',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => cards = v!),
                      ),
                      const Divider(height: 32),
                      Text(
                        'Selección por categoría',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final entry in categoryNames.entries)
                        if (data.any((p) => p.categoryId == entry.key))
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: data
                                .where((p) => p.categoryId == entry.key)
                                .every((p) => selected.contains(p.id)),
                            title: Text(entry.value),
                            subtitle: Text(
                              '${data.where((p) => p.categoryId == entry.key).length} producto(s)',
                            ),
                            onChanged: (value) => setState(() {
                              final ids = data
                                  .where((p) => p.categoryId == entry.key)
                                  .map((p) => p.id);
                              if (value == true) {
                                selected.addAll(ids);
                              } else {
                                selected.removeAll(ids);
                              }
                              ref
                                  .read(selectedProductIdsProvider.notifier)
                                  .replaceAll(selected);
                            }),
                          ),
                      const Divider(height: 24),
                      CheckboxListTile(
                        value: selected.length == data.length,
                        title: const Text('Todos los productos'),
                        onChanged: (v) => setState(() {
                          selected.clear();
                          if (v == true) selected.addAll(data.map((p) => p.id));
                          ref
                              .read(selectedProductIdsProvider.notifier)
                              .replaceAll(selected);
                        }),
                      ),
                      for (final p in data)
                        CheckboxListTile(
                          value: selected.contains(p.id),
                          title: Text(p.name),
                          subtitle: Text(p.sku),
                          onChanged: (v) => setState(() {
                            v! ? selected.add(p.id) : selected.remove(p.id);
                            ref
                                .read(selectedProductIdsProvider.notifier)
                                .replaceAll(selected);
                          }),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: PdfPreview(
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    pdfFileName: 'catalogo_serp.pdf',
                    build: (_) => CatalogPdfService().generate(
                      data.where((p) => selected.contains(p.id)).toList(),
                      CatalogPdfOptions(
                        companyName: companyName,
                        paymentMethods: paymentMethods,
                        agentName: agent.text,
                        agentPhone: phone.text,
                        cardsPerPage: cards,
                        categoryNames: categoryNames,
                        logoBytes: logoBytes,
                        backgroundColor: backgroundColor,
                        cardColor: cardColor,
                        accentColor: accentColor,
                        textColor: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _colorField(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) {
    const colors = <String, String>{
      '#FFFFFF': 'Blanco',
      '#F5F5F5': 'Gris claro',
      '#111111': 'Negro',
      '#3949AB': 'Índigo',
      '#1565C0': 'Azul',
      '#2E7D32': 'Verde',
      '#C62828': 'Rojo',
      '#F9A825': 'Amarillo',
    };
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final entry in colors.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Color(
                      int.parse('FF${entry.key.substring(1)}', radix: 16),
                    ),
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(entry.value),
              ],
            ),
          ),
      ],
      onChanged: (newValue) => onChanged(newValue!),
    );
  }
}
