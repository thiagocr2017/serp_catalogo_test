import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../di/product_providers.dart';
import '../../domain/entities/product.dart';
import '../controllers/product_list_controller.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key});
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
  final _moq = TextEditingController(text: '1');
  final _cbm = TextEditingController(text: '0');
  final _factoryCost = TextEditingController(text: '0');
  final _initialStock = TextEditingController(text: '0');
  final _reorderPoint = TextEditingController(text: '0');
  String? _categoryId;
  PackagingType _packagingType = PackagingType.unit;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _sku,
      _barcode,
      _name,
      _description,
      _unitPrice,
      _packagePrice,
      _moq,
      _cbm,
      _factoryCost,
      _initialStock,
      _reorderPoint,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int _cents(String value) => (double.parse(value) * 100).round();
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo requerido' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final product = Product(
        id: const Uuid().v4(),
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
        packagingType: _packagingType,
        cbmPerMoq: double.parse(_cbm.text),
        factoryCostInCents: _cents(_factoryCost.text),
        currentStock: 0,
        reorderPoint: int.parse(_reorderPoint.text),
        isActive: true,
        createdAt: DateTime.now().toUtc(),
      );
      await ref
          .read(saveProductProvider)
          .create(product, initialStock: int.parse(_initialStock.text));
      ref.invalidate(productListControllerProvider);
      if (mounted) {
        context.go('/products');
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
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo producto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
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
                      validator: (value) =>
                          value == null ? 'Seleccione una categoría' : null,
                      onChanged: (value) => setState(() => _categoryId = value),
                    ),
                  ),
                ),
                SizedBox(
                  width: 656,
                  child: TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                _field(
                  _unitPrice,
                  'Precio unitario USD',
                  number: true,
                  validator: _required,
                ),
                _field(_packagePrice, 'Precio paquete USD', number: true),
                _field(
                  _factoryCost,
                  'Costo fábrica USD',
                  number: true,
                  validator: _required,
                ),
                _field(_moq, 'MOQ', number: true, validator: _required),
                _field(_cbm, 'CBM por MOQ', number: true, validator: _required),
                _field(
                  _initialStock,
                  'Stock inicial',
                  number: true,
                  validator: _required,
                ),
                _field(
                  _reorderPoint,
                  'Punto de reorden',
                  number: true,
                  validator: _required,
                ),
                SizedBox(
                  width: 320,
                  child: DropdownButtonFormField<PackagingType>(
                    initialValue: _packagingType,
                    decoration: const InputDecoration(
                      labelText: 'Empaque',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: PackagingType.unit,
                        child: Text('Unidad'),
                      ),
                      DropdownMenuItem(
                        value: PackagingType.box,
                        child: Text('Caja'),
                      ),
                      DropdownMenuItem(
                        value: PackagingType.set,
                        child: Text('Set'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _packagingType = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => context.go('/products'),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
