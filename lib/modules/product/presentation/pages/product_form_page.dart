import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'dart:typed_data';

import '../../../configuration/configuration_module.dart';
import '../../../inventory/inventory_module.dart' as inventory;
import '../../di/product_providers.dart';
import '../../domain/entities/product.dart';
import '../controllers/product_list_controller.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({this.productId, super.key});
  final String? productId;
  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _unitPrice = TextEditingController();
  final _packagePrice = TextEditingController();
  final _promotionPrice = TextEditingController();
  final _promotionText = TextEditingController();
  final _moq = TextEditingController(text: '1');
  final _minimumSaleQuantity = TextEditingController(text: '1');
  final _cbm = TextEditingController(text: '0');
  final _factoryCost = TextEditingController(text: '0');
  final _initialStock = TextEditingController(text: '0');
  final _reorderPoint = TextEditingController(text: '0');
  String? _categoryId;
  String? _packagingPresentationId;
  bool _saving = false;
  bool _dirty = false;
  double _imagePositionX = 0.5;
  double _imagePositionY = 0.5;
  double _imageScale = 1;
  Uint8List? _imageBytes;
  Product? _existing;
  bool _loading = false;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() => _loading = true);
    final product = await ref.read(
      productByIdProvider(widget.productId!).future,
    );
    if (product != null && mounted) {
      _existing = product;
      _sku.text = product.sku;
      _barcode.text = product.barcode ?? '';
      _name.text = product.name;
      _description.text = product.description;
      _unitPrice.text = (product.unitPriceInCents / 100).toStringAsFixed(2);
      _packagePrice.text = product.packagePriceInCents == null
          ? ''
          : (product.packagePriceInCents! / 100).toStringAsFixed(2);
      if (product.promotionType == PromotionType.individual) {
        _promotionPrice.text = product.promotionPriceInCents == null
            ? ''
            : (product.promotionPriceInCents! / 100).toStringAsFixed(2);
        _promotionText.text = product.promotionText ?? '';
      }
      _moq.text = '${product.minimumOrderQuantity}';
      _minimumSaleQuantity.text = '${product.minimumSaleQuantity}';
      _cbm.text = '${product.cbmPerMoq}';
      _factoryCost.text = (product.factoryCostInCents / 100).toStringAsFixed(2);
      _reorderPoint.text = '${product.reorderPoint}';
      _categoryId = product.categoryId;
      _packagingPresentationId = product.packagingPresentationId;
      _imagePositionX = product.imagePositionX;
      _imagePositionY = product.imagePositionY;
      _imageScale = product.imageScale;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final controller in [
      _sku,
      _barcode,
      _name,
      _description,
      _unitPrice,
      _packagePrice,
      _promotionPrice,
      _promotionText,
      _moq,
      _minimumSaleQuantity,
      _cbm,
      _factoryCost,
      _initialStock,
      _reorderPoint,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Marca el formulario como modificado. No reconstruye por sí sola:
  /// los llamadores que necesitan refresco visual ya están en setState.
  void _markDirty() {
    _dirty = true;
  }

  double _decimal(String value) => double.parse(value.replaceAll(',', '.'));
  int? _tryCents(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.').trim());
    if (parsed == null) return null;
    return (parsed * 100).round();
  }

  int _cents(String value) => (_decimal(value) * 100).round();
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo requerido' : null;

  /// Margen en vivo a partir de costo de fábrica y precio unitario.
  ({int profitCents, double percent})? _margin() {
    final price = _tryCents(_unitPrice.text);
    final cost = _tryCents(_factoryCost.text);
    if (price == null || price <= 0 || cost == null) return null;
    final profit = price - cost;
    return (profitCents: profit, percent: profit / price * 100);
  }

  /// Descuento efectivo de la promoción individual sobre el precio unitario.
  double? _promoDiscount() {
    final price = _tryCents(_unitPrice.text);
    final promo = _tryCents(_promotionPrice.text);
    if (_promotionPrice.text.trim().isEmpty) return null;
    if (price == null || price <= 0 || promo == null || promo <= 0) {
      return null;
    }
    if (promo >= price) return null;
    return (1 - promo / price) * 100;
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar cambios'),
        content: const Text(
          'Tienes cambios sin guardar. Si sales ahora se perderán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _cancel() async {
    if (_saving) return;
    if (_dirty && mounted && !await _confirmDiscard()) return;
    if (mounted) context.go('/products');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _categoryId == null ||
        _packagingPresentationId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final productId = _existing?.id ?? const Uuid().v4();
      final imageUrl = _imageBytes == null
          ? _existing?.imageUrl
          : await ref
                .read(productImageServiceProvider)
                .replace(
                  sku: _sku.text,
                  bytes: _imageBytes!,
                  previousUrl: _existing?.imageUrl,
                );
      final product = Product(
        id: productId,
        sku: _sku.text.trim(),
        barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        name: _name.text.trim(),
        description: _description.text.trim(),
        categoryId: _categoryId!,
        unitPriceInCents: _cents(_unitPrice.text),
        packagePriceInCents: _packagePrice.text.trim().isEmpty
            ? null
            : _cents(_packagePrice.text),
        minimumOrderQuantity: int.parse(_moq.text),
        minimumSaleQuantity: int.parse(_minimumSaleQuantity.text),
        packagingPresentationId: _packagingPresentationId!,
        packagingPresentationName: ref
            .read(packagingPresentationDtosProvider)
            .value
            ?.where((item) => item.id == _packagingPresentationId)
            .firstOrNull
            ?.name,
        cbmPerMoq: _decimal(_cbm.text),
        factoryCostInCents: _cents(_factoryCost.text),
        imageUrl: imageUrl,
        imagePositionX: _imagePositionX,
        imagePositionY: _imagePositionY,
        imageScale: _imageScale,
        catalogSortOrder: _existing?.catalogSortOrder ?? 0,
        currentStock: _existing?.currentStock ?? 0,
        reorderPoint: int.parse(_reorderPoint.text),
        promotionPriceInCents: _promotionPrice.text.trim().isEmpty
            ? null
            : _cents(_promotionPrice.text),
        promotionText: _promotionText.text.trim().isEmpty
            ? null
            : _promotionText.text.trim(),
        promotionType: _promotionPrice.text.trim().isEmpty
            ? null
            : PromotionType.individual,
        isActive: _existing?.isActive ?? true,
        createdAt: _existing?.createdAt ?? DateTime.now().toUtc(),
        updatedAt: _isEditing ? DateTime.now().toUtc() : null,
      );
      if (_isEditing) {
        await ref.read(saveProductProvider).update(product);
        ref.invalidate(productByIdProvider(productId));
      } else {
        await ref
            .read(saveProductProvider)
            .create(product, initialStock: int.parse(_initialStock.text));
      }
      ref.invalidate(productListControllerProvider);
      ref
          .read(inventory.inventoryDataRevisionProvider.notifier)
          .notifyChanged();
      ref.invalidate(productTransactionsProvider(productId));
      ref.invalidate(productAuditProvider(productId));
      if (mounted) {
        context.go(_isEditing ? '/products/$productId' : '/products');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible guardar: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final presentations =
        ref.watch(packagingPresentationDtosProvider).value ?? [];
    if (_packagingPresentationId == null && presentations.isNotEmpty) {
      _packagingPresentationId = presentations.first.id;
    }
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (!mounted) return;
        if (await _confirmDiscard() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing
                ? 'Editar producto · ${_existing?.sku ?? ''}'
                : 'Nuevo producto',
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final halfWidth = constraints.maxWidth >= 700
                              ? 320.0
                              : constraints.maxWidth;
                          final fullWidth = constraints.maxWidth;
                          return Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _section(
                                  'Información general',
                                  'Identificación y descripción del producto.',
                                  halfWidth,
                                  [
                                    _field(
                                      _sku,
                                      'SKU',
                                      width: halfWidth,
                                      autofocus: !_isEditing,
                                      validator: _required,
                                    ),
                                    _field(
                                      _barcode,
                                      'Código de barras (opcional)',
                                      width: halfWidth,
                                    ),
                                    _field(
                                      _name,
                                      'Nombre',
                                      width: halfWidth,
                                      validator: _required,
                                    ),
                                    SizedBox(
                                      width: halfWidth,
                                      child: categories.when(
                                        loading: () =>
                                            const LinearProgressIndicator(),
                                        error: (e, _) => Text(
                                          'Error de categorías: $e',
                                        ),
                                        data: (items) =>
                                            DropdownButtonFormField<String>(
                                              initialValue: _categoryId,
                                              decoration:
                                                  const InputDecoration(
                                                    labelText: 'Categoría',
                                                    border:
                                                        OutlineInputBorder(),
                                                  ),
                                              items: [
                                                for (final item in items)
                                                  DropdownMenuItem(
                                                    value: item.id,
                                                    child: Text(item.name),
                                                  ),
                                              ],
                                              validator: (value) =>
                                                  value == null
                                                  ? 'Seleccione una categoría'
                                                  : null,
                                              onChanged: (value) => setState(() {
                                                _categoryId = value;
                                                _dirty = true;
                                              }),
                                            ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: fullWidth,
                                      child: TextFormField(
                                        controller: _description,
                                        maxLines: 3,
                                        onChanged: (_) => _markDirty(),
                                        decoration: const InputDecoration(
                                          labelText: 'Descripción para catálogo',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                _imageSection(fullWidth),
                                _section(
                                  'Precio de venta',
                                  'Lo que paga el cliente. El margen se calcula contra el costo de fábrica.',
                                  halfWidth,
                                  [
                                    _field(
                                      _unitPrice,
                                      'Precio unitario USD',
                                      width: halfWidth,
                                      number: true,
                                      validator: _required,
                                    ),
                                    _field(
                                      _packagePrice,
                                      'Precio por bulto USD (opcional)',
                                      width: halfWidth,
                                      number: true,
                                    ),
                                    _field(
                                      _minimumSaleQuantity,
                                      'Venta mínima al cliente',
                                      width: halfWidth,
                                      number: true,
                                      helper:
                                          'Unidades mínimas por venta.',
                                      validator: _required,
                                    ),
                                    SizedBox(
                                      width: halfWidth,
                                      child:
                                          DropdownButtonFormField<String>(
                                            key: ValueKey(
                                              _packagingPresentationId,
                                            ),
                                            initialValue:
                                                _packagingPresentationId,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  'Presentación de venta',
                                              border: OutlineInputBorder(),
                                            ),
                                            items: presentations
                                                .map(
                                                  (item) => DropdownMenuItem(
                                                    value: item.id,
                                                    child: Text(item.name),
                                                  ),
                                                )
                                                .toList(),
                                            validator: (value) => value == null
                                                ? presentations.isEmpty
                                                      ? 'No hay presentaciones: créalas en Configuración'
                                                      : 'Seleccione una presentación'
                                                : null,
                                            onChanged: (value) => setState(() {
                                              _packagingPresentationId = value;
                                              _dirty = true;
                                            }),
                                          ),
                                    ),
                                    SizedBox(
                                      width: fullWidth,
                                      child: _marginBanner(context),
                                    ),
                                  ],
                                ),
                                _section(
                                  'Costo y reposición',
                                  'Datos internos: no aparecen en el catálogo.',
                                  halfWidth,
                                  [
                                    _field(
                                      _factoryCost,
                                      'Costo de fábrica USD',
                                      width: halfWidth,
                                      number: true,
                                      validator: _required,
                                    ),
                                    _field(
                                      _moq,
                                      'MOQ al proveedor',
                                      width: halfWidth,
                                      number: true,
                                      helper:
                                          'Lote mínimo de compra para reponer.',
                                      validator: _required,
                                    ),
                                    _field(
                                      _cbm,
                                      'CBM por MOQ',
                                      width: halfWidth,
                                      number: true,
                                      helper:
                                          'Volumen del lote para fletes.',
                                      validator: _required,
                                    ),
                                    _field(
                                      _reorderPoint,
                                      'Punto de reorden',
                                      width: halfWidth,
                                      number: true,
                                      helper:
                                          'Avisa cuando el stock llegue aquí.',
                                      validator: _required,
                                    ),
                                  ],
                                ),
                                _section(
                                  'Promoción individual',
                                  'Tiene prioridad sobre cualquier promoción masiva vigente.',
                                  halfWidth,
                                  [
                                    _field(
                                      _promotionPrice,
                                      'Precio promocional USD (opcional)',
                                      width: halfWidth,
                                      number: true,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return null;
                                        }
                                        if (_tryCents(value) == null) {
                                          return 'Ingrese un número válido';
                                        }
                                        final price = _tryCents(
                                          _unitPrice.text,
                                        );
                                        final promo = _tryCents(value)!;
                                        if (price != null &&
                                            price > 0 &&
                                            promo >= price) {
                                          return 'Debe ser menor que el precio unitario';
                                        }
                                        return null;
                                      },
                                    ),
                                    SizedBox(
                                      width: fullWidth,
                                      child: TextFormField(
                                        controller: _promotionText,
                                        maxLines: 2,
                                        onChanged: (_) => _markDirty(),
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Condiciones de la promoción',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    if (_promoDiscount() != null)
                                      SizedBox(
                                        width: fullWidth,
                                        child: _discountBanner(context),
                                      ),
                                  ],
                                ),
                                if (_isEditing && _existing != null)
                                  _section(
                                    'Inventario',
                                    'El stock es de solo lectura y cambia únicamente mediante movimientos.',
                                    halfWidth,
                                    [
                                      SizedBox(
                                        width: halfWidth,
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Stock actual',
                                            border: OutlineInputBorder(),
                                          ),
                                          child: Text(
                                            '${_existing!.currentStock}',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (!_isEditing)
                                  _section(
                                    'Inventario inicial',
                                    'Crea el primer movimiento inmutable del inventario.',
                                    halfWidth,
                                    [
                                      _field(
                                        _initialStock,
                                        'Stock inicial',
                                        width: halfWidth,
                                        number: true,
                                        validator: _required,
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 28),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: _cancel,
                                      child: const Text('Cancelar'),
                                    ),
                                    const SizedBox(width: 12),
                                    FilledButton.icon(
                                      onPressed: _saving ? null : _save,
                                      icon: _saving
                                          ? const SizedBox.square(
                                              dimension: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.save),
                                      label: const Text('Guardar producto'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _marginBanner(BuildContext context) {
    final margin = _margin();
    final scheme = Theme.of(context).colorScheme;
    if (margin == null) {
      return Text(
        'Escribe costo y precio para ver el margen.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final positive = margin.profitCents >= 0;
    final color = positive ? Colors.green.shade700 : scheme.error;
    final sign = positive ? '+' : '−';
    final profit =
        '${margin.profitCents.abs() ~/ 100}.${((margin.profitCents.abs() % 100).toString().padLeft(2, '0'))}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Margen: $sign\$$profit USD ($sign${margin.percent.abs().toStringAsFixed(1)}%)'
        '${positive ? '' : ' · el precio no cubre el costo'}',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }

  Widget _discountBanner(BuildContext context) {
    final discount = _promoDiscount()!;
    return Text(
      'Descuento efectivo: −${discount.toStringAsFixed(0)}% sobre el precio unitario.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _imageSection(double fullWidth) {
    return Card(
      margin: const EdgeInsets.only(top: 18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Imagen del catálogo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Opcional. Se usa en pantallas y en el PDF.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final bytes = await ref
                            .read(productImageServiceProvider)
                            .selectAndCompress();
                        if (bytes != null && mounted) {
                          setState(() {
                            _imageBytes = bytes;
                            _dirty = true;
                          });
                        }
                      } catch (error) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('No se pudo abrir la imagen: $error'),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _imageBytes == null
                    ? 'Seleccionar imagen'
                    : 'Imagen lista (${(_imageBytes!.length / 1024).round()} KB)',
              ),
            ),
            if (_imageBytes != null || _existing?.imageUrl != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 280,
                  height: 280,
                  margin: const EdgeInsets.only(top: 12),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: FractionalTranslation(
                    translation: Offset(
                      (_imagePositionX - .5) * .9,
                      (_imagePositionY - .5) * .9,
                    ),
                    child: Transform.scale(
                      scale: _imageScale,
                      child: _imageBytes != null
                          ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                          : Image.network(
                              _existing!.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: fullWidth > 560 ? 560 : fullWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Reposicionar imagen',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Mueve el punto focal; la vista previa muestra el recorte usado en pantallas y PDF.',
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 82, child: Text('Horizontal')),
                        Expanded(
                          child: Slider(
                            value: _imagePositionX,
                            onChanged: (value) => setState(() {
                              _imagePositionX = value;
                              _dirty = true;
                            }),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 82, child: Text('Zoom')),
                        IconButton(
                          tooltip: 'Alejar',
                          onPressed: _imageScale <= 1
                              ? null
                              : () => setState(() {
                                  _imageScale = (_imageScale - 0.1)
                                      .clamp(1, 3)
                                      .toDouble();
                                  _dirty = true;
                                }),
                          icon: const Icon(Icons.zoom_out),
                        ),
                        Expanded(
                          child: Slider(
                            min: 1,
                            max: 3,
                            divisions: 20,
                            label: '${_imageScale.toStringAsFixed(1)}×',
                            value: _imageScale,
                            onChanged: (value) => setState(() {
                              _imageScale = value;
                              _dirty = true;
                            }),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Acercar',
                          onPressed: _imageScale >= 3
                              ? null
                              : () => setState(() {
                                  _imageScale = (_imageScale + 0.1)
                                      .clamp(1, 3)
                                      .toDouble();
                                  _dirty = true;
                                }),
                          icon: const Icon(Icons.zoom_in),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 82, child: Text('Vertical')),
                        Expanded(
                          child: Slider(
                            value: _imagePositionY,
                            onChanged: (value) => setState(() {
                              _imagePositionY = value;
                              _dirty = true;
                            }),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _imagePositionX = 0.5;
                        _imagePositionY = 0.5;
                        _imageScale = 1;
                        _dirty = true;
                      }),
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('Centrar imagen'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(
    String title,
    String description,
    double fieldWidth,
    List<Widget> fields,
  ) {
    return Card(
      margin: const EdgeInsets.only(top: 18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 18),
            Wrap(spacing: 16, runSpacing: 16, children: fields),
          ],
        ),
      ),
    );
  }

  SizedBox _field(
    TextEditingController controller,
    String label, {
    required double width,
    bool number = false,
    bool autofocus = false,
    String? helper,
    String? Function(String?)? validator,
  }) => SizedBox(
    width: width,
    child: TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      validator: number
          ? (value) {
              final requiredError = validator?.call(value);
              if (requiredError != null) return requiredError;
              if (value != null &&
                  value.trim().isNotEmpty &&
                  double.tryParse(value.replaceAll(',', '.')) == null) {
                return 'Ingrese un número válido';
              }
              return null;
            }
          : validator,
      onChanged: (_) => setState(() => _dirty = true),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
