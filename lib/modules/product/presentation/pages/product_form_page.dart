import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'dart:typed_data';

import '../../../../core/configuration/settings_providers.dart';
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
  PackagingType _packagingType = PackagingType.unit;
  bool _saving = false;
  bool _isActive = true;
  double _imagePositionX = 0.5;
  double _imagePositionY = 0.5;
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
      _packagingType = product.packagingType;
      _isActive = product.isActive;
      _imagePositionX = product.imagePositionX;
      _imagePositionY = product.imagePositionY;
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

  double _decimal(String value) => double.parse(value.replaceAll(',', '.'));
  int _cents(String value) => (_decimal(value) * 100).round();
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo requerido' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) {
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
        packagingType: _packagingType,
        cbmPerMoq: _decimal(_cbm.text),
        factoryCostInCents: _cents(_factoryCost.text),
        imageUrl: imageUrl,
        imagePositionX: _imagePositionX,
        imagePositionY: _imagePositionY,
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
        isActive: _isActive,
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
    final settings = ref.watch(businessSettingsProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar producto' : 'Nuevo producto'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            try {
                              final bytes = await ref
                                  .read(productImageServiceProvider)
                                  .selectAndCompress();
                              if (bytes != null && mounted) {
                                setState(() => _imageBytes = bytes);
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo abrir la imagen: $error',
                                    ),
                                  ),
                                );
                              }
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
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: _imageBytes != null
                            ? Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                                alignment: _imageAlignment,
                              )
                            : Image.network(
                                _existing!.imageUrl!,
                                fit: BoxFit.cover,
                                alignment: _imageAlignment,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(
                      width: 560,
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
                              const SizedBox(
                                width: 82,
                                child: Text('Horizontal'),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _imagePositionX,
                                  onChanged: (value) =>
                                      setState(() => _imagePositionX = value),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 82,
                                child: Text('Vertical'),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _imagePositionY,
                                  onChanged: (value) =>
                                      setState(() => _imagePositionY = value),
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _imagePositionX = 0.5;
                              _imagePositionY = 0.5;
                            }),
                            icon: const Icon(Icons.center_focus_strong),
                            label: const Text('Centrar imagen'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _section(
                    'Información general',
                    'Identificación y descripción del producto.',
                    [
                      _field(_sku, 'SKU', validator: _required),
                      _field(_barcode, 'Código de barras'),
                      _field(_name, 'Nombre', validator: _required),
                      SizedBox(
                        width: 320,
                        child: categories.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Error de categorías: $e'),
                          data: (items) => DropdownButtonFormField<String>(
                            initialValue: _categoryId,
                            decoration: const InputDecoration(
                              labelText: 'Categoría',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final item in items)
                                DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                            ],
                            validator: (value) => value == null
                                ? 'Seleccione una categoría'
                                : null,
                            onChanged: (value) =>
                                setState(() => _categoryId = value),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 656,
                        child: TextFormField(
                          controller: _description,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Descripción para catálogo',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _section(
                    'Información comercial y de catálogo',
                    'Datos que utiliza el cliente para comprar el producto.',
                    [
                      _field(
                        _unitPrice,
                        'Precio unitario USD',
                        number: true,
                        validator: _required,
                      ),
                      _field(
                        _packagePrice,
                        'Precio por presentación USD',
                        number: true,
                      ),
                      _field(
                        _minimumSaleQuantity,
                        'Cantidad mínima de venta',
                        number: true,
                        validator: _required,
                      ),
                      SizedBox(
                        width: 320,
                        child: DropdownButtonFormField<PackagingType>(
                          initialValue: _packagingType,
                          decoration: const InputDecoration(
                            labelText: 'Presentación de venta',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: PackagingType.unit,
                              child: Text(
                                settings?.packagingUnitLabel ?? 'Unidad',
                              ),
                            ),
                            DropdownMenuItem(
                              value: PackagingType.box,
                              child: Text(
                                settings?.packagingBoxLabel ?? 'Caja',
                              ),
                            ),
                            DropdownMenuItem(
                              value: PackagingType.set,
                              child: Text(settings?.packagingSetLabel ?? 'Set'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _packagingType = value!),
                        ),
                      ),
                    ],
                  ),
                  _section(
                    'Información de recompra e importación',
                    'Datos internos que no aparecen en la lista ni en el catálogo.',
                    [
                      _field(
                        _factoryCost,
                        'Costo de fábrica USD',
                        number: true,
                        validator: _required,
                      ),
                      _field(
                        _moq,
                        'MOQ de recompra',
                        number: true,
                        validator: _required,
                      ),
                      _field(
                        _cbm,
                        'CBM por MOQ',
                        number: true,
                        validator: _required,
                      ),
                      _field(
                        _reorderPoint,
                        'Punto de reorden',
                        number: true,
                        validator: _required,
                      ),
                    ],
                  ),
                  _section(
                    'Promoción individual',
                    'Tiene prioridad sobre cualquier promoción masiva vigente.',
                    [
                      _field(
                        _promotionPrice,
                        'Precio promocional USD',
                        number: true,
                      ),
                      SizedBox(
                        width: 656,
                        child: TextFormField(
                          controller: _promotionText,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Condiciones de la promoción',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isEditing && _existing != null)
                    _section(
                      'Estado',
                      'Un producto reactivado vuelve a aparecer entre los productos activos.',
                      [
                        SizedBox(
                          width: 320,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _isActive,
                            title: Text(
                              _isActive
                                  ? 'Producto activo'
                                  : 'Producto inactivo',
                            ),
                            onChanged: (value) =>
                                setState(() => _isActive = value),
                          ),
                        ),
                      ],
                    ),
                  if (_isEditing && _existing != null)
                    _section(
                      'Inventario',
                      'El stock es de solo lectura y cambia únicamente mediante movimientos.',
                      [
                        SizedBox(
                          width: 320,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Stock actual',
                              border: OutlineInputBorder(),
                            ),
                            child: Text('${_existing!.currentStock}'),
                          ),
                        ),
                      ],
                    ),
                  if (!_isEditing)
                    _section(
                      'Inventario inicial',
                      'Crea el primer movimiento inmutable del inventario.',
                      [
                        _field(
                          _initialStock,
                          'Stock inicial',
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
                        onPressed: _saving
                            ? null
                            : () => context.go('/products'),
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
            ),
    );
  }

  Alignment get _imageAlignment =>
      Alignment((_imagePositionX * 2) - 1, (_imagePositionY * 2) - 1);

  Widget _section(String title, String description, List<Widget> fields) {
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
    bool number = false,
    String? Function(String?)? validator,
  }) => SizedBox(
    width: 320,
    child: TextFormField(
      controller: controller,
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
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
