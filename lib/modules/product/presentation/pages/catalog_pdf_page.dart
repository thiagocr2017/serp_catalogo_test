import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../core/utilities/phone_number.dart';
import '../../../configuration/configuration_module.dart';
import '../../../../core/identity/identity_context_provider.dart';
import '../../../sales/sales_module.dart';
import '../../di/product_providers.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';
import '../../../../shared/utilities/search_query.dart';
import '../../services/catalog_pdf_service.dart';
import '../controllers/product_list_controller.dart';

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
  CatalogImageFit imageFit = CatalogImageFit.cover;
  int cards = 4;
  List<Product>? products;
  Map<String, String> categoryNames = const {};
  Uint8List? logoBytes;
  int preferencesVersion = 1;
  List<SalesAgentDto> catalogAgents = const [];
  String? selectedAgentId;
  Timer? _preferencesTimer;
  bool _savingPreferences = false;
  bool _savePreferencesAgain = false;
  bool _preferencesSaved = true;
  bool _savingPdf = false;
  bool _savingOrder = false;
  bool _refreshingCatalog = false;
  final ValueNotifier<bool> _previewReady = ValueNotifier(false);
  bool _previewFailed = false;
  int _previewGeneration = 0;
  bool _orderDirty = false;
  List<String> _savedCatalogOrder = [];
  List<String> _savedCategoryOrder = [];
  int _tab = 0;
  static const double _kMinRailWidth = 410;
  double _railWidth = 410;
  String categorySelectionSearch = '';
  String productSelectionSearch = '';
  String categoryOrderSearch = '';
  String productOrderSearch = '';
  final selected = <String>{};
  final reorderSelection = <String>{};
  final catalogOrder = <String>[];
  final categoryOrder = <String>[];
  final categoryReorderSelection = <String>{};
  final _categorySelectionScrollController = ScrollController();
  final _productSelectionScrollController = ScrollController();
  final _categoryOrderScrollController = ScrollController();
  final _productOrderScrollController = ScrollController();

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
    final settings = await ref.read(businessSettingsDtoProvider.future);
    final configuration = ref.read(configurationApiProvider);
    final preferences = await configuration.getCatalogPreferences();
    final agents = await ref
        .read(salesApiProvider)
        .getAgents(const SalesAgentQuery(activeOnly: true));
    final storedLogo = await configuration.downloadCatalogLogo();
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
              if (category != 0) return category;
              final product = a.catalogSortOrder.compareTo(b.catalogSortOrder);
              return product != 0 ? product : a.name.compareTo(b.name);
            });
      setState(() {
        products = eligible;
        categoryNames = loadedCategoryNames;
        companyName = settings.companyName;
        paymentMethods = settings.paymentMethods;
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
        preferencesVersion = preferences.version;
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
            (categories
                    .where(
                      (category) =>
                          eligible.any((p) => p.categoryId == category.id),
                    )
                    .toList()
                  ..sort(
                    (a, b) => a.catalogSortOrder.compareTo(b.catalogSortOrder),
                  ))
                .map((category) => category.id),
          );
        _savedCatalogOrder = [...catalogOrder];
        _savedCategoryOrder = [...categoryOrder];
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
    _previewReady.dispose();
    _categorySelectionScrollController.dispose();
    _productSelectionScrollController.dispose();
    _categoryOrderScrollController.dispose();
    _productOrderScrollController.dispose();
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
      final saved = await ref
          .read(configurationApiProvider)
          .saveCatalogPreferences(
            SaveCatalogPreferencesCommand(
              expectedVersion: preferencesVersion,
              identity: ref.read(identityContextProvider),
              values: CatalogDesignPreferencesInput(
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
              ),
            ),
          );
      if (mounted) {
        setState(() {
          preferencesVersion = saved.version;
          _preferencesSaved = true;
        });
      }
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

  Future<void> _selectAgent(String? value) async {
    _preferencesTimer?.cancel();
    if (!_preferencesSaved) await _savePreferences();
    try {
      final saved = await ref
          .read(configurationApiProvider)
          .selectCatalogAgent(
            SelectCatalogAgentCommand(
              agentId: value,
              expectedVersion: preferencesVersion,
              identity: ref.read(identityContextProvider),
            ),
          );
      final selectedAgent = catalogAgents
          .where((item) => item.id == value)
          .firstOrNull;
      if (mounted) {
        setState(() {
          preferencesVersion = saved.version;
          selectedAgentId = value;
          agent.text = selectedAgent?.name ?? '';
          phone.text = selectedAgent?.phone ?? '';
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo seleccionar el agente: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = products;
    final previewGeneration = _previewGeneration;
    final rawMaxRail = MediaQuery.sizeOf(context).width - 480;
    final maxRail = rawMaxRail < _kMinRailWidth ? _kMinRailWidth : rawMaxRail;
    final railWidth = _railWidth.clamp(_kMinRailWidth, maxRail).toDouble();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Generar catálogo PDF'),
          actions: data == null
              ? null
              : [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${selected.length} de ${data.length} productos · '
                      '${_selectedCategoryCount(data)} categorías',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: FilledButton.icon(
                      onPressed: _savingPdf ? null : () => _savePdf(data),
                      icon: _savingPdf
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_alt_outlined),
                      label: const Text('Guardar PDF'),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
        ),
        bottomNavigationBar: _orderDirty
            ? SafeArea(
                top: false,
                child: Material(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Cambios de orden sin guardar'),
                        ),
                        TextButton.icon(
                          onPressed: _savingOrder ? null : _discardOrderChanges,
                          icon: const Icon(Icons.undo),
                          label: const Text('Descartar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _savingOrder ? null : _saveOrderChanges,
                          icon: _savingOrder
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: const Text('Guardar'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
        body: data == null
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  SizedBox(
                    width: railWidth,
                    child: Column(
                      children: [
                        Material(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: TabBar(
                            onTap: (index) => setState(() => _tab = index),
                            tabs: const [
                              Tab(
                                icon: Icon(Icons.business_outlined),
                                text: 'Datos',
                              ),
                              Tab(
                                icon: Icon(Icons.palette_outlined),
                                text: 'Diseño',
                              ),
                              Tab(
                                icon: Icon(Icons.checklist_outlined),
                                text: 'Selección',
                              ),
                              Tab(
                                icon: Icon(Icons.sort_outlined),
                                text: 'Orden',
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: IndexedStack(
                            index: _tab,
                            children: [
                              ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  Text(
                                    'Datos de empresa',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
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
                                    trailing: const Icon(
                                      Icons.settings_outlined,
                                    ),
                                  ),
                                  const Text(
                                    'Estos datos se administran en Configuración y se usan automáticamente.',
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    onTap: () => context.go('/settings'),
                                    leading: const Icon(
                                      Icons.business_outlined,
                                    ),
                                    title: Text(
                                      logoBytes == null
                                          ? 'Logo no configurado'
                                          : 'Logo configurado',
                                    ),
                                    subtitle: const Text(
                                      'El logo se administra en Configuración.',
                                    ),
                                    trailing: const Icon(Icons.open_in_new),
                                  ),
                                  const Divider(height: 28),
                                  Text(
                                    'Datos del catálogo',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
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
                                          onChanged: _selectAgent,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Administrar agentes',
                                        onPressed: () =>
                                            context.go('/sales/agents'),
                                        icon: const Icon(
                                          Icons.manage_accounts_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (selectedAgentId != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'WhatsApp: ${displayPhone(phone.text)}',
                                      ),
                                    ),
                                ],
                              ),
                              ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  Text(
                                    'Diseño de la plantilla',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  _TemplateColorField(
                                    label: 'Fondo',
                                    value: backgroundColor,
                                    onChanged: (value) => _updatePreference(
                                      () => backgroundColor = value,
                                    ),
                                  ),
                                  _TemplateColorField(
                                    label: 'Tarjetas',
                                    value: cardColor,
                                    onChanged: (value) => _updatePreference(
                                      () => cardColor = value,
                                    ),
                                  ),
                                  _TemplateColorField(
                                    label: 'Elemento de diseño',
                                    value: designAccentColor,
                                    onChanged: (value) => _updatePreference(
                                      () => designAccentColor = value,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Colores de fuentes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  _TemplateColorField(
                                    label: 'Fuente de texto',
                                    value: textColor,
                                    onChanged: (value) => _updatePreference(
                                      () => textColor = value,
                                    ),
                                  ),
                                  _TemplateColorField(
                                    label: 'Fuente destacada',
                                    value: highlightTextColor,
                                    onChanged: (value) => _updatePreference(
                                      () => highlightTextColor = value,
                                    ),
                                  ),
                                  _TemplateColorField(
                                    label: 'Fuente secundaria',
                                    value: secondaryTextColor,
                                    onChanged: (value) => _updatePreference(
                                      () => secondaryTextColor = value,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'Promociones',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  _TemplateColorField(
                                    label: 'Elemento de promoción',
                                    value: promotionColor,
                                    onChanged: (value) => _updatePreference(
                                      () => promotionColor = value,
                                    ),
                                  ),
                                  _TemplateColorField(
                                    label: 'Fuente de promoción',
                                    value: promotionTextColor,
                                    onChanged: (value) => _updatePreference(
                                      () => promotionTextColor = value,
                                    ),
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
                                    key: ValueKey('imageFit-$imageFit'),
                                    initialValue: imageFit,
                                    decoration: const InputDecoration(
                                      labelText: 'Ajuste de fotografías',
                                      helperText: 'Define cómo llenan el marco del producto.',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: CatalogImageFit.cover,
                                        child: Text(
                                          'Rellenar marco (puede recortar)',
                                        ),
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
                                    onChanged: (value) => _updatePreference(
                                      () => imageFit = value!,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<int>(
                                    key: ValueKey('cards-$cards'),
                                    initialValue: cards,
                                    decoration: const InputDecoration(
                                      labelText: 'Tarjetas por página',
                                    ),
                                    items: const [0, 1, 2, 4, 6]
                                        .map(
                                          (v) => DropdownMenuItem(
                                            value: v,
                                            child: Text(
                                              v == 0
                                                  ? 'Lista compacta'
                                                  : '$v tarjetas',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        _updatePreference(() => cards = v!),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton.icon(
                                        onPressed: _resetDesign,
                                        icon: const Icon(
                                          Icons.restart_alt_outlined,
                                        ),
                                        label: const Text('Restablecer diseño'),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: _savingPreferences
                                            ? null
                                            : _savePreferences,
                                        icon: _savingPreferences
                                            ? const SizedBox.square(
                                                dimension: 18,
                                                child:
                                                    CircularProgressIndicator(
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
                                    ],
                                  ),
                                ],
                              ),
                              ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
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
                                            Icon(
                                              Icons.inventory_2_outlined,
                                              size: 38,
                                            ),
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
                                  const SizedBox(height: 16),
                                  Text(
                                    'Selección por categoría',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  _CatalogSearchField(
                                    hint: 'Buscar categoría',
                                    onChanged: (value) => setState(
                                      () => categorySelectionSearch = value,
                                    ),
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
                                      controller:
                                          _categorySelectionScrollController,
                                      child: ListView(
                                        controller:
                                            _categorySelectionScrollController,
                                        primary: false,
                                        children: [
                                          for (final entry
                                              in categoryNames.entries)
                                            if (data.any(
                                                  (p) =>
                                                      p.categoryId == entry.key,
                                                ) &&
                                                _matches(
                                                  entry.value,
                                                  categorySelectionSearch,
                                                ))
                                              CheckboxListTile(
                                                dense: true,
                                                contentPadding: EdgeInsets.zero,
                                                value: data
                                                    .where(
                                                      (p) =>
                                                          p.categoryId ==
                                                          entry.key,
                                                    )
                                                    .every(
                                                      (p) => selected.contains(
                                                        p.id,
                                                      ),
                                                    ),
                                                title: Text(entry.value),
                                                subtitle: Text(
                                                  '${data.where((p) => p.categoryId == entry.key).length} producto(s)',
                                                ),
                                                onChanged: (value) => setState(() {
                                                  final ids = data
                                                      .where(
                                                        (p) =>
                                                            p.categoryId ==
                                                            entry.key,
                                                      )
                                                      .map((p) => p.id);
                                                  value == true
                                                      ? selected.addAll(ids)
                                                      : selected.removeAll(ids);
                                                  ref
                                                      .read(
                                                        selectedProductIdsProvider
                                                            .notifier,
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Selección por producto',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
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
                                    onChanged: (value) => setState(
                                      () => productSelectionSearch = value,
                                    ),
                                  ),
                                  CheckboxListTile(
                                    value: selected.length == data.length,
                                    title: const Text('Todos los productos'),
                                    onChanged: (v) => setState(() {
                                      selected.clear();
                                      if (v == true) {
                                        selected.addAll(data.map((p) => p.id));
                                      }
                                      ref
                                          .read(
                                            selectedProductIdsProvider.notifier,
                                          )
                                          .replaceAll(selected);
                                    }),
                                  ),
                                  SizedBox(
                                    height: 320,
                                    child: Scrollbar(
                                      controller:
                                          _productSelectionScrollController,
                                      child: ListView(
                                        controller:
                                            _productSelectionScrollController,
                                        primary: false,
                                        children: [
                                          for (final p in data)
                                            if (_matchesProduct(
                                              p,
                                              productSelectionSearch,
                                            ))
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
                                                        selectedProductIdsProvider
                                                            .notifier,
                                                      )
                                                      .replaceAll(selected);
                                                }),
                                              ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Orden del catálogo',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: _orderDirty
                                            ? 'Guarda o descarta los cambios antes de actualizar'
                                            : 'Actualizar catálogo',
                                        onPressed:
                                            _orderDirty ||
                                                _savingOrder ||
                                                _refreshingCatalog
                                            ? null
                                            : _refreshCatalog,
                                        icon: _refreshingCatalog
                                            ? const SizedBox.square(
                                                dimension: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.refresh),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Orden de categorías',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const Text(
                                    'Al mover una categoría se mueve con todos sus productos.',
                                  ),
                                  _CatalogSearchField(
                                    hint: 'Buscar categoría para ordenar',
                                    onChanged: (value) => setState(
                                      () => categoryOrderSearch = value,
                                    ),
                                  ),
                                  _orderButtons(
                                    selection: categoryReorderSelection,
                                    onUp: () => _moveCategories(-1),
                                    onDown: () => _moveCategories(1),
                                    onClear: () => setState(
                                      () => categoryReorderSelection.clear(),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 180,
                                    child: Scrollbar(
                                      controller:
                                          _categoryOrderScrollController,
                                      child: ListView(
                                        controller:
                                            _categoryOrderScrollController,
                                        primary: false,
                                        children: [
                                          for (final categoryId
                                              in categoryOrder)
                                            if (_matches(
                                              categoryNames[categoryId] ?? '',
                                              categoryOrderSearch,
                                            ))
                                              CheckboxListTile(
                                                dense: true,
                                                contentPadding: EdgeInsets.zero,
                                                value: categoryReorderSelection
                                                    .contains(categoryId),
                                                title: Text(
                                                  categoryNames[categoryId] ??
                                                      'Sin categoría',
                                                ),
                                                onChanged: (value) => setState(() {
                                                  value == true
                                                      ? categoryReorderSelection
                                                            .add(categoryId)
                                                      : categoryReorderSelection
                                                            .remove(categoryId);
                                                }),
                                              ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 24),
                                  Text(
                                    'Orden dentro de cada categoría',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const Text(
                                    'Marca uno o varios productos y muévelos juntos. Las categorías siempre permanecen agrupadas.',
                                  ),
                                  _CatalogSearchField(
                                    hint: 'Buscar producto para ordenar',
                                    onChanged: (value) => setState(
                                      () => productOrderSearch = value,
                                    ),
                                  ),
                                  _orderButtons(
                                    selection: reorderSelection,
                                    onUp: () => _moveMarked(data, -1),
                                    onDown: () => _moveMarked(data, 1),
                                    onClear: () =>
                                        setState(reorderSelection.clear),
                                  ),
                                  SizedBox(
                                    height: 340,
                                    child: Scrollbar(
                                      controller: _productOrderScrollController,
                                      child: ListView(
                                        controller:
                                            _productOrderScrollController,
                                        primary: false,
                                        children: [
                                          for (final product
                                              in _orderedProducts(data))
                                            if (selected.contains(product.id) &&
                                                _matchesProduct(
                                                  product,
                                                  productOrderSearch,
                                                ))
                                              CheckboxListTile(
                                                dense: true,
                                                contentPadding: EdgeInsets.zero,
                                                value: reorderSelection
                                                    .contains(product.id),
                                                title: Text(product.name),
                                                subtitle: Text(
                                                  '${categoryNames[product.categoryId] ?? 'Sin categoría'} · ${product.sku}',
                                                ),
                                                onChanged: (value) =>
                                                    setState(() {
                                                      value == true
                                                          ? reorderSelection
                                                                .add(product.id)
                                                          : reorderSelection
                                                                .remove(
                                                                  product.id,
                                                                );
                                                    }),
                                              ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildResizeHandle(maxRail),
                  Expanded(
                    child: Stack(
                      children: [
                        PdfPreview(
                          key: ValueKey(previewGeneration),
                          allowPrinting: false,
                          allowSharing: false,
                          canChangePageFormat: false,
                          canChangeOrientation: false,
                          canDebug: false,
                          pdfFileName: 'catalogo_serp.pdf',
                          loadingWidget: _CatalogRenderProgress(
                            onReady: () =>
                                _onCatalogPreviewReady(previewGeneration),
                          ),
                          onError: (_, error) {
                            _previewFailed = true;
                            return Center(
                              child: Text(
                                'No se pudo renderizar el catálogo: $error',
                              ),
                            );
                          },
                          actions: [
                            IconButton(
                              tooltip: 'Guardar PDF',
                              onPressed: () => _savePdf(data),
                              icon: const Icon(Icons.download_outlined),
                            ),
                          ],
                          build: (_) => _generatePdf(data),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _previewReady,
                          builder: (context, ready, _) => ready
                              ? Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: _CatalogReadyProgress(
                                    onDismiss: () =>
                                        _previewReady.value = false,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<Uint8List> _generatePdf(List<Product> data) async {
    _previewFailed = false;
    if (_previewReady.value) _previewReady.value = false;
    return CatalogPdfService().generate(
      _orderedProducts(data)
          .where((product) => selected.contains(product.id))
          .toList(),
      CatalogPdfOptions(
        companyName: companyName,
        paymentMethods: paymentMethods,
        agentName: agent.text,
        agentPhone: displayPhone(phone.text),
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
        imageFit: imageFit,
      ),
      fontLoader: rootBundle.load,
    );
  }

  void _onCatalogPreviewReady(int generation) {
    if (mounted &&
        generation == _previewGeneration &&
        !_previewFailed &&
        !_previewReady.value) {
      _previewReady.value = true;
    }
  }

  Future<void> _savePdf(List<Product> data) async {
    if (_savingPdf) return;
    setState(() => _savingPdf = true);
    try {
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
    } finally {
      if (mounted) setState(() => _savingPdf = false);
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

  int _selectedCategoryCount(List<Product> data) => data
      .where((product) => selected.contains(product.id))
      .map((product) => product.categoryId)
      .toSet()
      .length;

  void _resetDesign() {
    _updatePreference(() {
      backgroundColor = '#FFFFFF';
      cardColor = '#FFFFFF';
      designAccentColor = '#3949AB';
      textColor = '#111111';
      highlightTextColor = '#1565C0';
      secondaryTextColor = '#616161';
      promotionColor = '#C62828';
      promotionTextColor = '#FFFFFF';
      promotionPreviousPriceColor = '#757575';
      promotionPriceColor = '#C62828';
      promotionDescriptionColor = '#C62828';
      imageFit = CatalogImageFit.cover;
      cards = 4;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diseño restablecido a los valores por defecto.'),
      ),
    );
  }

  Widget _buildResizeHandle(double maxRail) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (details) {
        setState(() {
          final next = _railWidth + details.delta.dx;
          _railWidth = next.clamp(_kMinRailWidth, maxRail).toDouble();
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Tooltip(
          message: 'Arrastra para redimensionar el panel',
          child: Container(
            width: 8,
            height: double.infinity,
            color: scheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Container(
              width: 2,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _matches(String value, String query) {
    final term = effectiveSearchQuery(query).toLowerCase();
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

  Future<void> _saveOrderChanges() async {
    if (!_orderDirty || _savingOrder) return;
    setState(() => _savingOrder = true);
    try {
      final completeProductOrder = await _completeProductOrder();
      final completeCategoryOrder = await _completeCategoryOrder();
      await ref
          .read(productRepositoryProvider)
          .saveCatalogOrder(
            productIds: completeProductOrder,
            categoryIds: completeCategoryOrder,
          );
      if (mounted) {
        setState(() {
          _savedCatalogOrder = [...catalogOrder];
          _savedCategoryOrder = [...categoryOrder];
          _orderDirty = false;
        });
      }
      ref.invalidate(categoriesProvider);
      await ref.read(productListControllerProvider.notifier).refresh();
      try {
        await _reloadCatalogOrder(preserveOrder: true);
        if (mounted) {
          setState(() {
            _previewReady.value = false;
            _previewGeneration++;
          });
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'El orden se guardó, pero no se pudo actualizar el catálogo: $error',
              ),
            ),
          );
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orden del catálogo guardado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el orden: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  void _discardOrderChanges() {
    setState(() {
      catalogOrder
        ..clear()
        ..addAll(_savedCatalogOrder);
      categoryOrder
        ..clear()
        ..addAll(_savedCategoryOrder);
      _orderDirty = false;
      reorderSelection.clear();
      categoryReorderSelection.clear();
    });
  }

  bool _sameOrder(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  Future<List<String>> _completeProductOrder() async {
    final allProducts = await ref.read(getProductsProvider)(
      const ProductQuery(),
    );
    final productById = {
      for (final product in allProducts) product.id: product,
    };
    final visibleIndex = {
      for (var index = 0; index < catalogOrder.length; index++)
        catalogOrder[index]: index,
    };
    final categoryIndex = {
      for (var index = 0; index < categoryOrder.length; index++)
        categoryOrder[index]: index,
    };
    final categories = await ref.read(categoriesProvider.future);
    final persistedCategoryIndex = {
      for (final category in categories)
        category.id: categoryIndex[category.id] ?? category.catalogSortOrder,
    };
    final productIndex = <String, int>{};
    var nextProductIndex = 0;
    for (final categoryId in categoryOrder) {
      for (final productId in catalogOrder) {
        final product = productById[productId];
        if (product?.categoryId == categoryId) {
          productIndex[productId] = nextProductIndex++;
        }
      }
    }
    allProducts.sort((a, b) {
      final categoryOrder = (persistedCategoryIndex[a.categoryId] ?? 0)
          .compareTo(persistedCategoryIndex[b.categoryId] ?? 0);
      if (categoryOrder != 0) return categoryOrder;
      final productOrder =
          (productIndex[a.id] ?? visibleIndex[a.id] ?? a.catalogSortOrder)
              .compareTo(
                productIndex[b.id] ?? visibleIndex[b.id] ?? b.catalogSortOrder,
              );
      return productOrder != 0 ? productOrder : a.id.compareTo(b.id);
    });
    return allProducts.map((product) => product.id).toList();
  }

  Future<List<String>> _completeCategoryOrder() async {
    final categories = await ref.read(categoriesProvider.future);
    final visibleIds = categoryOrder.toSet();
    final visibleOrder = {
      for (var index = 0; index < categoryOrder.length; index++)
        categoryOrder[index]: index,
    };
    categories.sort((a, b) {
      final aVisible = visibleIds.contains(a.id);
      final bVisible = visibleIds.contains(b.id);
      if (aVisible != bVisible) return aVisible ? -1 : 1;
      final aOrder = visibleOrder[a.id] ?? a.catalogSortOrder;
      final bOrder = visibleOrder[b.id] ?? b.catalogSortOrder;
      final order = aOrder.compareTo(bOrder);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return categories.map((category) => category.id).toList();
  }

  Future<void> _refreshCatalog() async {
    if (_orderDirty || _savingOrder || _refreshingCatalog) return;
    setState(() => _refreshingCatalog = true);
    try {
      ref.invalidate(categoriesProvider);
      await ref.read(productListControllerProvider.notifier).refresh();
      _previewReady.value = false;
      await _reloadCatalogOrder();
      if (mounted) {
        setState(() {
          _previewReady.value = false;
          _previewGeneration++;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el catálogo: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingCatalog = false);
    }
  }

  Future<void> _reloadCatalogOrder({bool preserveOrder = false}) async {
    final data = await ref.read(getProductsProvider)(
      const ProductQuery(isActive: true),
    );
    final categories = await ref.read(categoriesProvider.future);
    final eligibleCategories =
        categories
            .where(
              (category) => data.any(
                (product) =>
                    product.isActive &&
                    !product.isOutOfStock &&
                    product.categoryId == category.id,
              ),
            )
            .toList()
          ..sort((a, b) {
            final position = a.catalogSortOrder.compareTo(b.catalogSortOrder);
            return position != 0 ? position : a.id.compareTo(b.id);
          });
    final persistedCategoryIndex = {
      for (var index = 0; index < eligibleCategories.length; index++)
        eligibleCategories[index].id: index,
    };
    final eligible =
        data
            .where((product) => product.isActive && !product.isOutOfStock)
            .toList()
          ..sort((a, b) {
            final categoryPosition =
                (preserveOrder
                        ? categoryOrder.indexOf(a.categoryId)
                        : persistedCategoryIndex[a.categoryId] ?? 0)
                    .compareTo(
                      preserveOrder
                          ? categoryOrder.indexOf(b.categoryId)
                          : persistedCategoryIndex[b.categoryId] ?? 0,
                    );
            if (categoryPosition != 0) return categoryPosition;
            final productPosition = preserveOrder
                ? catalogOrder
                      .indexOf(a.id)
                      .compareTo(catalogOrder.indexOf(b.id))
                : a.catalogSortOrder.compareTo(b.catalogSortOrder);
            return productPosition != 0
                ? productPosition
                : a.name.compareTo(b.name);
          });
    if (!mounted) return;
    setState(() {
      products = eligible;
      categoryNames = {
        for (final category in categories) category.id: category.name,
      };
      if (!preserveOrder) {
        catalogOrder
          ..clear()
          ..addAll(eligible.map((product) => product.id));
        categoryOrder
          ..clear()
          ..addAll(eligibleCategories.map((category) => category.id));
        _savedCatalogOrder = [...catalogOrder];
        _savedCategoryOrder = [...categoryOrder];
        _orderDirty = false;
      } else {
        final eligibleIds = eligible.map((product) => product.id).toSet();
        catalogOrder.removeWhere((id) => !eligibleIds.contains(id));
        for (final product in eligible) {
          if (!catalogOrder.contains(product.id)) catalogOrder.add(product.id);
        }
        final eligibleCategoryIds = categories
            .where(
              (category) =>
                  eligible.any((product) => product.categoryId == category.id),
            )
            .map((category) => category.id)
            .toSet();
        categoryOrder.removeWhere((id) => !eligibleCategoryIds.contains(id));
        for (final category in categories) {
          if (eligibleCategoryIds.contains(category.id) &&
              !categoryOrder.contains(category.id)) {
            categoryOrder.add(category.id);
          }
        }
      }
    });
  }

  void _moveCategories(int direction) {
    setState(() {
      _moveSelectedItems(categoryOrder, categoryReorderSelection, direction);
      _orderDirty =
          !_sameOrder(categoryOrder, _savedCategoryOrder) ||
          !_sameOrder(catalogOrder, _savedCatalogOrder);
    });
  }

  void _moveMarked(List<Product> data, int direction) {
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
      _orderDirty =
          !_sameOrder(categoryOrder, _savedCategoryOrder) ||
          !_sameOrder(catalogOrder, _savedCatalogOrder);
    });
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

class _CatalogRenderProgress extends StatefulWidget {
  const _CatalogRenderProgress({required this.onReady});

  final VoidCallback onReady;

  @override
  State<_CatalogRenderProgress> createState() => _CatalogRenderProgressState();
}

class _CatalogRenderProgressState extends State<_CatalogRenderProgress> {
  @override
  void dispose() {
    final onReady = widget.onReady;
    WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Renderizando catálogo...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogReadyProgress extends StatefulWidget {
  const _CatalogReadyProgress({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_CatalogReadyProgress> createState() => _CatalogReadyProgressState();
}

class _CatalogReadyProgressState extends State<_CatalogReadyProgress> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LinearProgressIndicator(value: 1),
            const SizedBox(height: 4),
            Text(
              'Catálogo listo · 100%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
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
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
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
