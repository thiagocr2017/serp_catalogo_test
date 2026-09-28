import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../core/configuration/settings_providers.dart';
import '../../../../core/configuration/catalog_preferences.dart';
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
  String promotionPreviousPriceColor = '#757575';
  String promotionPriceColor = '#C62828';
  String promotionDescriptionColor = '#C62828';
  String packagingUnitLabel = 'Unidad';
  String packagingBoxLabel = 'Caja';
  String packagingSetLabel = 'Set';
  CatalogImageFit imageFit = CatalogImageFit.cover;
  int cards = 4;
  List<Product>? products;
  Map<String, String> categoryNames = const {};
  Uint8List? logoBytes;
  String? logoUrl;
  List<CatalogAgent> catalogAgents = const [];
  String? selectedAgentId;
  Timer? _preferencesTimer;
  bool _savingPreferences = false;
  bool _savePreferencesAgain = false;
  bool _preferencesSaved = true;
  String categorySelectionSearch = '';
  String productSelectionSearch = '';
  String categoryOrderSearch = '';
  String productOrderSearch = '';
  final selected = <String>{};
  final reorderSelection = <String>{};
  final catalogOrder = <String>[];
  final categoryOrder = <String>[];
  final categoryReorderSelection = <String>{};

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
    final settingsRepository = ref.read(settingsRepositoryProvider);
    final preferences = await settingsRepository.getCatalogPreferences();
    final agents = await settingsRepository.getCatalogAgents();
    final storedLogo = await settingsRepository.downloadCatalogLogo(
      preferences.logoUrl,
    );
    if (mounted) {
      final sharedSelection = ref.read(selectedProductIdsProvider);
      final loadedCategoryNames = {
        for (final category in categories) category.id: category.name,
      };
      final eligible =
          data
              .where((product) => product.isActive && !product.isOutOfStock)
              .toList()
            ..sort((a, b) {
              final categoryA = categories.firstWhere(
                (item) => item.id == a.categoryId,
              );
              final categoryB = categories.firstWhere(
                (item) => item.id == b.categoryId,
              );
              final category = categoryA.catalogSortOrder.compareTo(
                categoryB.catalogSortOrder,
              );
              return category != 0
                  ? category
                  : a.catalogSortOrder.compareTo(b.catalogSortOrder);
            });
      setState(() {
        products = eligible;
        categoryNames = loadedCategoryNames;
        companyName = settings.companyName;
        paymentMethods = settings.paymentMethods;
        packagingUnitLabel = settings.packagingUnitLabel;
        packagingBoxLabel = settings.packagingBoxLabel;
        packagingSetLabel = settings.packagingSetLabel;
        cards = preferences.cardsPerPage;
        backgroundColor = preferences.backgroundColor;
        cardColor = preferences.cardColor;
        designAccentColor = preferences.designAccentColor;
        textColor = preferences.textColor;
        highlightTextColor = preferences.highlightTextColor;
        secondaryTextColor = preferences.secondaryTextColor;
        promotionColor = preferences.promotionColor;
        promotionTextColor = preferences.promotionTextColor;
        promotionPreviousPriceColor = preferences.promotionPreviousPriceColor;
        promotionPriceColor = preferences.promotionPriceColor;
        promotionDescriptionColor = preferences.promotionDescriptionColor;
        imageFit = CatalogImageFit.values.firstWhere(
          (value) => value.name == preferences.imageFit,
          orElse: () => CatalogImageFit.cover,
        );
        logoUrl = preferences.logoUrl;
        logoBytes = storedLogo;
        catalogAgents = agents;
        selectedAgentId =
            agents.any((item) => item.id == preferences.selectedAgentId)
            ? preferences.selectedAgentId
            : null;
        final selectedAgent = agents
            .where((item) => item.id == selectedAgentId)
            .firstOrNull;
        if (selectedAgent != null) {
          agent.text = selectedAgent.name;
          phone.text = selectedAgent.phone;
        }
        catalogOrder
          ..clear()
          ..addAll(eligible.map((product) => product.id));
        categoryOrder
          ..clear()
          ..addAll(
            categories
                .where(
                  (category) =>
                      eligible.any((p) => p.categoryId == category.id),
                )
                .map((category) => category.id),
          );
        selected.addAll(
          sharedSelection.isEmpty
              ? eligible.map((p) => p.id)
              : eligible
                    .where((p) => sharedSelection.contains(p.id))
                    .map((p) => p.id),
        );
      });
    }
  }

  @override
  void dispose() {
    if (_preferencesTimer?.isActive == true) {
      unawaited(_savePreferences());
    }
    _preferencesTimer?.cancel();
    agent.dispose();
    phone.dispose();
    super.dispose();
  }

  void _updatePreference(VoidCallback update) {
    setState(() {
      update();
      _preferencesSaved = false;
    });
    _preferencesTimer?.cancel();
    _preferencesTimer = Timer(
      const Duration(milliseconds: 500),
      _savePreferences,
    );
  }

  Future<void> _savePreferences() async {
    if (_savingPreferences) {
      _savePreferencesAgain = true;
      return;
    }
    if (mounted) setState(() => _savingPreferences = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .saveCatalogPreferences(
            CatalogPreferences(
              cardsPerPage: cards,
              backgroundColor: backgroundColor,
              cardColor: cardColor,
              designAccentColor: designAccentColor,
              textColor: textColor,
              highlightTextColor: highlightTextColor,
              secondaryTextColor: secondaryTextColor,
              promotionColor: promotionColor,
              promotionTextColor: promotionTextColor,
              promotionPreviousPriceColor: promotionPreviousPriceColor,
              promotionPriceColor: promotionPriceColor,
              promotionDescriptionColor: promotionDescriptionColor,
              imageFit: imageFit.name,
              logoUrl: logoUrl,
              selectedAgentId: selectedAgentId,
            ),
          );
      if (mounted) setState(() => _preferencesSaved = true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el diseño: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
      if (_savePreferencesAgain) {
        _savePreferencesAgain = false;
        unawaited(_savePreferences());
      }
    }
  }

  Future<void> _createAgent() async {
    final name = TextEditingController();
    final contact = TextEditingController(text: '+506');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo agente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: contact,
              decoration: const InputDecoration(labelText: 'WhatsApp'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, name.text.trim().isNotEmpty),
            child: const Text('Guardar agente'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final created = await ref
          .read(settingsRepositoryProvider)
          .createCatalogAgent(name: name.text, phone: contact.text);
      if (mounted) {
        setState(() {
          catalogAgents = [...catalogAgents, created]
            ..sort((a, b) => a.name.compareTo(b.name));
          selectedAgentId = created.id;
          agent.text = created.name;
          phone.text = created.phone;
        });
        await _savePreferences();
      }
    }
    name.dispose();
    contact.dispose();
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
                            final extension = file.name.split('.').last;
                            final url = await ref
                                .read(settingsRepositoryProvider)
                                .uploadCatalogLogo(bytes, extension);
                            if (mounted) {
                              setState(() {
                                logoBytes = bytes;
                                logoUrl = url;
                              });
                              await _savePreferences();
                            }
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
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(selectedAgentId),
                              initialValue: selectedAgentId,
                              decoration: const InputDecoration(
                                labelText: 'Agente del catálogo',
                              ),
                              items: catalogAgents
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item.id,
                                      child: Text(item.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                final selectedAgent = catalogAgents
                                    .where((item) => item.id == value)
                                    .firstOrNull;
                                _updatePreference(() {
                                  selectedAgentId = value;
                                  agent.text = selectedAgent?.name ?? '';
                                  phone.text = selectedAgent?.phone ?? '';
                                });
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'Crear agente',
                            onPressed: _createAgent,
                            icon: const Icon(Icons.person_add_alt_1),
                          ),
                        ],
                      ),
                      if (selectedAgentId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('WhatsApp: ${phone.text}'),
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
                            _updatePreference(() => backgroundColor = value),
                      ),
                      _TemplateColorField(
                        label: 'Tarjetas',
                        value: cardColor,
                        onChanged: (value) =>
                            _updatePreference(() => cardColor = value),
                      ),
                      _TemplateColorField(
                        label: 'Elemento de diseño',
                        value: designAccentColor,
                        onChanged: (value) =>
                            _updatePreference(() => designAccentColor = value),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Colores de fuentes',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      _TemplateColorField(
                        label: 'Fuente de texto',
                        value: textColor,
                        onChanged: (value) =>
                            _updatePreference(() => textColor = value),
                      ),
                      _TemplateColorField(
                        label: 'Fuente destacada',
                        value: highlightTextColor,
                        onChanged: (value) =>
                            _updatePreference(() => highlightTextColor = value),
                      ),
                      _TemplateColorField(
                        label: 'Fuente secundaria',
                        value: secondaryTextColor,
                        onChanged: (value) =>
                            _updatePreference(() => secondaryTextColor = value),
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
                            _updatePreference(() => promotionColor = value),
                      ),
                      _TemplateColorField(
                        label: 'Fuente de promoción',
                        value: promotionTextColor,
                        onChanged: (value) =>
                            _updatePreference(() => promotionTextColor = value),
                      ),
                      _TemplateColorField(
                        label: 'Precio anterior (secundario)',
                        value: promotionPreviousPriceColor,
                        onChanged: (value) => _updatePreference(
                          () => promotionPreviousPriceColor = value,
                        ),
                      ),
                      _TemplateColorField(
                        label: 'Precio actual (principal)',
                        value: promotionPriceColor,
                        onChanged: (value) => _updatePreference(
                          () => promotionPriceColor = value,
                        ),
                      ),
                      _TemplateColorField(
                        label: 'Texto de promoción (principal)',
                        value: promotionDescriptionColor,
                        onChanged: (value) => _updatePreference(
                          () => promotionDescriptionColor = value,
                        ),
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
                        onChanged: (value) =>
                            _updatePreference(() => imageFit = value!),
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
                        onChanged: (v) => _updatePreference(() => cards = v!),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: _savingPreferences
                              ? null
                              : _savePreferences,
                          icon: _savingPreferences
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _preferencesSaved
                                      ? Icons.cloud_done_outlined
                                      : Icons.save_outlined,
                                ),
                          label: Text(
                            _preferencesSaved
                                ? 'Diseño guardado'
                                : 'Guardar diseño',
                          ),
                        ),
                      ),
                      const Divider(height: 32),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Los productos inactivos o agotados se excluyen automáticamente del catálogo.',
                        ),
                      ),
                      if (data.isEmpty) ...[
                        const SizedBox(height: 12),
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 38),
                                SizedBox(height: 8),
                                Text(
                                  'No hay productos disponibles para el catálogo.',
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Crea productos activos con existencias para habilitar la selección y el orden.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const Divider(height: 32),
                      Text(
                        'Selección por categoría',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      _CatalogSearchField(
                        hint: 'Buscar categoría',
                        onChanged: (value) =>
                            setState(() => categorySelectionSearch = value),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: selected.isEmpty
                              ? null
                              : _clearCatalogSelection,
                          icon: const Icon(Icons.deselect),
                          label: const Text('Limpiar selección'),
                        ),
                      ),
                      SizedBox(
                        height: 220,
                        child: Scrollbar(
                          child: ListView(
                            children: [
                              for (final entry in categoryNames.entries)
                                if (data.any(
                                      (p) => p.categoryId == entry.key,
                                    ) &&
                                    _matches(
                                      entry.value,
                                      categorySelectionSearch,
                                    ))
                                  CheckboxListTile(
                                    dense: true,
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
                                          .where(
                                            (p) => p.categoryId == entry.key,
                                          )
                                          .map((p) => p.id);
                                      value == true
                                          ? selected.addAll(ids)
                                          : selected.removeAll(ids);
                                      ref
                                          .read(
                                            selectedProductIdsProvider.notifier,
                                          )
                                          .replaceAll(selected);
                                    }),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selección por producto',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          TextButton.icon(
                            onPressed: selected.isEmpty
                                ? null
                                : _clearCatalogSelection,
                            icon: const Icon(Icons.deselect),
                            label: const Text('Limpiar'),
                          ),
                        ],
                      ),
                      _CatalogSearchField(
                        hint: 'Buscar por nombre, SKU o categoría',
                        onChanged: (value) =>
                            setState(() => productSelectionSearch = value),
                      ),
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
                      SizedBox(
                        height: 320,
                        child: Scrollbar(
                          child: ListView(
                            children: [
                              for (final p in data)
                                if (_matchesProduct(p, productSelectionSearch))
                                  CheckboxListTile(
                                    dense: true,
                                    value: selected.contains(p.id),
                                    title: Text(p.name),
                                    subtitle: Text(p.sku),
                                    onChanged: (v) => setState(() {
                                      v!
                                          ? selected.add(p.id)
                                          : selected.remove(p.id);
                                      ref
                                          .read(
                                            selectedProductIdsProvider.notifier,
                                          )
                                          .replaceAll(selected);
                                    }),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 32),
                      Text(
                        'Orden de categorías',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'Al mover una categoría se mueve con todos sus productos.',
                      ),
                      _CatalogSearchField(
                        hint: 'Buscar categoría para ordenar',
                        onChanged: (value) =>
                            setState(() => categoryOrderSearch = value),
                      ),
                      _orderButtons(
                        selection: categoryReorderSelection,
                        onUp: () => _moveCategories(-1),
                        onDown: () => _moveCategories(1),
                        onClear: () =>
                            setState(() => categoryReorderSelection.clear()),
                      ),
                      SizedBox(
                        height: 180,
                        child: Scrollbar(
                          child: ListView(
                            children: [
                              for (final categoryId in categoryOrder)
                                if (_matches(
                                  categoryNames[categoryId] ?? '',
                                  categoryOrderSearch,
                                ))
                                  CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: categoryReorderSelection.contains(
                                      categoryId,
                                    ),
                                    title: Text(
                                      categoryNames[categoryId] ??
                                          'Sin categoría',
                                    ),
                                    onChanged: (value) => setState(() {
                                      value == true
                                          ? categoryReorderSelection.add(
                                              categoryId,
                                            )
                                          : categoryReorderSelection.remove(
                                              categoryId,
                                            );
                                    }),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      Text(
                        'Orden dentro de cada categoría',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'Marca uno o varios productos y muévelos juntos. Las categorías siempre permanecen agrupadas.',
                      ),
                      _CatalogSearchField(
                        hint: 'Buscar producto para ordenar',
                        onChanged: (value) =>
                            setState(() => productOrderSearch = value),
                      ),
                      _orderButtons(
                        selection: reorderSelection,
                        onUp: () => _moveMarked(data, -1),
                        onDown: () => _moveMarked(data, 1),
                        onClear: () => setState(reorderSelection.clear),
                      ),
                      SizedBox(
                        height: 340,
                        child: Scrollbar(
                          child: ListView(
                            children: [
                              for (final product in _orderedProducts(data))
                                if (selected.contains(product.id) &&
                                    _matchesProduct(
                                      product,
                                      productOrderSearch,
                                    ))
                                  CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: reorderSelection.contains(
                                      product.id,
                                    ),
                                    title: Text(product.name),
                                    subtitle: Text(
                                      '${categoryNames[product.categoryId] ?? 'Sin categoría'} · ${product.sku}',
                                    ),
                                    onChanged: (value) => setState(() {
                                      value == true
                                          ? reorderSelection.add(product.id)
                                          : reorderSelection.remove(product.id);
                                    }),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: PdfPreview(
                    allowPrinting: false,
                    allowSharing: false,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    pdfFileName: 'catalogo_serp.pdf',
                    actions: [
                      IconButton(
                        tooltip: 'Guardar PDF',
                        onPressed: () => _savePdf(data),
                        icon: const Icon(Icons.download_outlined),
                      ),
                    ],
                    build: (_) => _generatePdf(data),
                  ),
                ),
              ],
            ),
    );
  }

  Future<Uint8List> _generatePdf(List<Product> data) =>
      CatalogPdfService().generate(
        _orderedProducts(data)
            .where((product) => selected.contains(product.id))
            .toList(),
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
          promotionPreviousPriceColor: promotionPreviousPriceColor,
          promotionPriceColor: promotionPriceColor,
          promotionDescriptionColor: promotionDescriptionColor,
          packagingLabels: {
            PackagingType.unit: packagingUnitLabel,
            PackagingType.box: packagingBoxLabel,
            PackagingType.set: packagingSetLabel,
          },
          imageFit: imageFit,
        ),
      );

  Future<void> _savePdf(List<Product> data) async {
    final location = await getSaveLocation(
      suggestedName: 'catalogo_serp.pdf',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Documento PDF', extensions: ['pdf']),
      ],
    );
    if (location == null) return;
    final bytes = await _generatePdf(data);
    await File(location.path).writeAsBytes(bytes, flush: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF guardado en ${location.path}')),
      );
    }
  }

  List<Product> _orderedProducts(List<Product> data) {
    final byId = {for (final product in data) product.id: product};
    return [
      for (final categoryId in categoryOrder)
        for (final id in catalogOrder)
          if (byId[id]?.categoryId == categoryId) byId[id]!,
    ];
  }

  void _clearCatalogSelection() {
    setState(selected.clear);
    ref.read(selectedProductIdsProvider.notifier).clear();
  }

  bool _matches(String value, String query) {
    final term = query.trim().toLowerCase();
    return term.isEmpty || value.toLowerCase().contains(term);
  }

  bool _matchesProduct(Product product, String query) {
    final category = categoryNames[product.categoryId] ?? '';
    return _matches('${product.name} ${product.sku} $category', query);
  }

  Widget _orderButtons({
    required Set<String> selection,
    required VoidCallback onUp,
    required VoidCallback onDown,
    required VoidCallback onClear,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: selection.isEmpty ? null : onUp,
        icon: const Icon(Icons.arrow_upward),
        label: const Text('Subir'),
      ),
      OutlinedButton.icon(
        onPressed: selection.isEmpty ? null : onDown,
        icon: const Icon(Icons.arrow_downward),
        label: const Text('Bajar'),
      ),
      TextButton.icon(
        onPressed: selection.isEmpty ? null : onClear,
        icon: const Icon(Icons.deselect),
        label: const Text('Limpiar'),
      ),
    ],
  );

  Future<void> _persistOrder() async {
    try {
      await ref
          .read(productRepositoryProvider)
          .saveCatalogOrder(
            productIds: catalogOrder,
            categoryIds: categoryOrder,
          );
      ref.invalidate(categoriesProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el orden: $error')),
        );
      }
    }
  }

  Future<void> _moveCategories(int direction) async {
    setState(() {
      _moveSelectedItems(categoryOrder, categoryReorderSelection, direction);
    });
    await _persistOrder();
  }

  Future<void> _moveMarked(List<Product> data, int direction) async {
    final byId = {for (final product in data) product.id: product};
    setState(() {
      if (direction < 0) {
        for (var index = 1; index < catalogOrder.length; index++) {
          final current = catalogOrder[index];
          final previous = catalogOrder[index - 1];
          if (reorderSelection.contains(current) &&
              !reorderSelection.contains(previous) &&
              byId[current]?.categoryId == byId[previous]?.categoryId) {
            catalogOrder[index - 1] = current;
            catalogOrder[index] = previous;
          }
        }
      } else {
        for (var index = catalogOrder.length - 2; index >= 0; index--) {
          final current = catalogOrder[index];
          final next = catalogOrder[index + 1];
          if (reorderSelection.contains(current) &&
              !reorderSelection.contains(next) &&
              byId[current]?.categoryId == byId[next]?.categoryId) {
            catalogOrder[index + 1] = current;
            catalogOrder[index] = next;
          }
        }
      }
    });
    await _persistOrder();
  }

  void _moveSelectedItems(
    List<String> items,
    Set<String> selection,
    int direction,
  ) {
    if (direction < 0) {
      for (var index = 1; index < items.length; index++) {
        if (selection.contains(items[index]) &&
            !selection.contains(items[index - 1])) {
          final value = items.removeAt(index);
          items.insert(index - 1, value);
        }
      }
    } else {
      for (var index = items.length - 2; index >= 0; index--) {
        if (selection.contains(items[index]) &&
            !selection.contains(items[index + 1])) {
          final value = items.removeAt(index);
          items.insert(index + 1, value);
        }
      }
    }
  }
}

class _CatalogSearchField extends StatefulWidget {
  const _CatalogSearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_CatalogSearchField> createState() => _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends State<_CatalogSearchField> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextField(
      controller: controller,
      onChanged: (value) {
        setState(() {});
        widget.onChanged(value);
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                onPressed: () {
                  controller.clear();
                  setState(() {});
                  widget.onChanged('');
                },
                icon: const Icon(Icons.close),
              ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
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
