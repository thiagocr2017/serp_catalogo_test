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
  String designAccentColor = '#3949AB';
  String textColor = '#111111';
  String highlightTextColor = '#1565C0';
  String secondaryTextColor = '#616161';
  String promotionColor = '#C62828';
  String promotionTextColor = '#FFFFFF';
  CatalogImageFit imageFit = CatalogImageFit.cover;
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
                        'Diseño de la plantilla',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      _TemplateColorField(
                        label: 'Fondo',
                        value: backgroundColor,
                        onChanged: (value) =>
                            setState(() => backgroundColor = value),
                      ),
                      _TemplateColorField(
                        label: 'Tarjetas',
                        value: cardColor,
                        onChanged: (value) => setState(() => cardColor = value),
                      ),
                      _TemplateColorField(
                        label: 'Elemento de diseño',
                        value: designAccentColor,
                        onChanged: (value) =>
                            setState(() => designAccentColor = value),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Colores de fuentes',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      _TemplateColorField(
                        label: 'Fuente de texto',
                        value: textColor,
                        onChanged: (value) => setState(() => textColor = value),
                      ),
                      _TemplateColorField(
                        label: 'Fuente destacada',
                        value: highlightTextColor,
                        onChanged: (value) =>
                            setState(() => highlightTextColor = value),
                      ),
                      _TemplateColorField(
                        label: 'Fuente secundaria',
                        value: secondaryTextColor,
                        onChanged: (value) =>
                            setState(() => secondaryTextColor = value),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Promociones',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      _TemplateColorField(
                        label: 'Elemento de promoción',
                        value: promotionColor,
                        onChanged: (value) =>
                            setState(() => promotionColor = value),
                      ),
                      _TemplateColorField(
                        label: 'Fuente de promoción',
                        value: promotionTextColor,
                        onChanged: (value) =>
                            setState(() => promotionTextColor = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<CatalogImageFit>(
                        initialValue: imageFit,
                        decoration: const InputDecoration(
                          labelText: 'Ajuste de fotografías',
                          helperText:
                              'Define cómo llenan el marco del producto.',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: CatalogImageFit.cover,
                            child: Text('Rellenar marco (puede recortar)'),
                          ),
                          DropdownMenuItem(
                            value: CatalogImageFit.contain,
                            child: Text('Mostrar imagen completa'),
                          ),
                          DropdownMenuItem(
                            value: CatalogImageFit.fitWidth,
                            child: Text('Ajustar al ancho'),
                          ),
                        ],
                        onChanged: (value) => setState(() => imageFit = value!),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: cards,
                        decoration: const InputDecoration(
                          labelText: 'Tarjetas por página',
                        ),
                        items: const [0, 1, 2, 4, 6]
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
                        accentColor: designAccentColor,
                        textColor: textColor,
                        highlightTextColor: highlightTextColor,
                        secondaryTextColor: secondaryTextColor,
                        promotionColor: promotionColor,
                        promotionTextColor: promotionTextColor,
                        imageFit: imageFit,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _TemplateColorField extends StatefulWidget {
  const _TemplateColorField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TemplateColorField> createState() => _TemplateColorFieldState();
}

class _TemplateColorFieldState extends State<_TemplateColorField> {
  late final TextEditingController _controller;

  static final _hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _TemplateColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _color => _parseColor(widget.value) ?? Colors.white;

  Color? _parseColor(String value) {
    if (!_hexPattern.hasMatch(value)) return null;
    return Color(int.parse('FF${value.substring(1)}', radix: 16));
  }

  String _toHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _applyText(String value) {
    final normalized = value.startsWith('#') ? value : '#$value';
    if (!_hexPattern.hasMatch(normalized)) return;
    final upper = normalized.toUpperCase();
    if (_controller.text != upper) {
      _controller.value = TextEditingValue(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
    widget.onChanged(upper);
  }

  Future<void> _openPicker() async {
    var red = _color.r.toDouble() * 255;
    var green = _color.g.toDouble() * 255;
    var blue = _color.b.toDouble() * 255;
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final color = Color.fromARGB(
            255,
            red.round(),
            green.round(),
            blue.round(),
          );
          Widget slider(String label, double value, ValueChanged<double> set) {
            return Row(
              children: [
                SizedBox(width: 22, child: Text(label)),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 255,
                    value: value,
                    onChanged: (next) => setDialogState(() => set(next)),
                  ),
                ),
                SizedBox(width: 34, child: Text(value.round().toString())),
              ],
            );
          }

          return AlertDialog(
            title: Text('Color de ${widget.label.toLowerCase()}'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _toHex(color),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  slider('R', red, (value) => red = value),
                  slider('G', green, (value) => green = value),
                  slider('B', blue, (value) => blue = value),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, color),
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );
    if (selected != null) _applyText(_toHex(selected));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextFormField(
        controller: _controller,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: '#RRGGBB',
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: _openPicker,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _color,
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
          suffixIcon: IconButton(
            tooltip: 'Abrir selector de color',
            onPressed: _openPicker,
            icon: const Icon(Icons.palette_outlined),
          ),
        ),
        validator: (value) => _hexPattern.hasMatch(value ?? '')
            ? null
            : 'Usa un código como #1565C0',
        onChanged: _applyText,
        onFieldSubmitted: _applyText,
      ),
    );
  }
}
