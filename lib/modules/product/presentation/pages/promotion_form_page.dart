import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/product.dart';
import '../../../../shared/navigation/unsaved_changes_guard.dart';

import '../../domain/entities/category.dart';


import '../../di/product_providers.dart';
import '../../di/promotion_providers.dart';
import '../../domain/entities/product_query.dart';
import '../../domain/entities/bulk_promotion.dart';


import '../../../../shared/navigation/unsaved_changes_guard.dart';

class PromotionFormPage extends ConsumerStatefulWidget {
  const PromotionFormPage({super.key, this.id});
  final String? id;

  @override
  ConsumerState<PromotionFormPage> createState() => _PromotionFormPageState();
}

class _PromotionFormPageState extends ConsumerState<PromotionFormPage> {
  final _name = TextEditingController();
  final _discount = TextEditingController();
  final _conditions = TextEditingController();
  final _startDate = TextEditingController();
  final _endDate = TextEditingController();

  final _selectedProducts = <String>{};
  final _selectedCategories = <String>{};
  bool _appliesToAll = true;
  bool _isActive = true;
  bool _saving = false;
  
  BulkPromotion? _existing;
  List<Product>? _allProducts;
  List<Category>? _allCategories;

  @override
  void initState() {
    super.initState();
    _load();
  }
  
  Future<void> _load() async {
    try {
      final products = await ref.read(getProductsProvider)(const ProductQuery(isActive: true));
      final categories = await ref.read(categoriesProvider.future);
      
      BulkPromotion? existing;
      if (widget.id != null) {
         final promotions = await ref.read(promotionsProvider.future);
         existing = promotions.firstWhere((p) => p.id == widget.id);
      }

      if (existing != null) {
        _name.text = existing.name;
        _discount.text = existing.discountPercentage.toStringAsFixed(1);
        _conditions.text = existing.conditionsText;
        _appliesToAll = existing.appliesToAllProducts;
        _isActive = existing.isActive;
        _selectedProducts.addAll(existing.productIds);
        _selectedCategories.addAll(existing.categoryIds);
        _startDate.text = existing.startDate?.toIso8601String().split('T').first ?? '';
        _endDate.text = existing.endDate.toIso8601String().split('T').first;
      }
      
      if (mounted) {
        setState(() {
          _allProducts = products;
          _allCategories = categories;
          _existing = existing;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando: $e')));
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _discount.dispose();
    _conditions.dispose();
    _startDate.dispose();
    _endDate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final discount = double.tryParse(_discount.text);
    if (name.isEmpty || discount == null || discount <= 0 || discount >= 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre y el descuento (1-99) son obligatorios.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(promotionRepositoryProvider);
      final promotion = BulkPromotion(
        id: _existing?.id ?? '',
        name: name,
        discountPercentage: discount,
        conditionsText: _conditions.text.trim(),
        startDate: _startDate.text.isNotEmpty ? DateTime.tryParse(_startDate.text) : null,
        endDate: _endDate.text.isNotEmpty ? DateTime.tryParse(_endDate.text) ?? DateTime.now().add(const Duration(days: 365)) : DateTime.now().add(const Duration(days: 365)),
        appliesToAllProducts: _appliesToAll,
        isActive: _isActive,
        productIds: _selectedProducts,
        categoryIds: _selectedCategories,
      );
      if (_existing == null) {
        await repo.createPromotion(promotion, productIds: _selectedProducts, categoryIds: _selectedCategories);
      } else {
        await repo.updatePromotion(promotion, productIds: _selectedProducts, categoryIds: _selectedCategories);
      }
      ref.invalidate(promotionsProvider);
      ref.invalidate(getProductsProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $error')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_allProducts == null || _allCategories == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_existing == null ? 'Nueva Promoción' : 'Editar Promoción'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: _saving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
        label: const Text('Guardar'),
      ),
      body: 
        ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre de la promoción'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _discount,
              decoration: const InputDecoration(labelText: 'Descuento (%)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _conditions,
              decoration: const InputDecoration(labelText: 'Texto de condiciones comerciales'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startDate,
                    decoration: const InputDecoration(labelText: 'Fecha de inicio (YYYY-MM-DD)', hintText: 'Opcional'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _endDate,
                    decoration: const InputDecoration(labelText: 'Fecha de fin (YYYY-MM-DD)', hintText: 'Opcional'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Promoción activa'),
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
            ),
            SwitchListTile(
              title: const Text('Aplica a todo el catálogo'),
              value: _appliesToAll,
              onChanged: (val) => setState(() => _appliesToAll = val),
            ),
            if (!_appliesToAll) ...[
              const Divider(),
              const Text('Categorías seleccionadas:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  for (final cat in _allCategories!)
                    FilterChip(
                      label: Text(cat.name),
                      selected: _selectedCategories.contains(cat.id),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) _selectedCategories.add(cat.id);
                          else _selectedCategories.remove(cat.id);
                        });
                      },
                    )
                ],
              ),
              const SizedBox(height: 16),
              const Text('Productos específicos:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  for (final prod in _allProducts!)
                    FilterChip(
                      label: Text(prod.sku),
                      selected: _selectedProducts.contains(prod.id),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) _selectedProducts.add(prod.id);
                          else _selectedProducts.remove(prod.id);
                        });
                      },
                    )
                ],
              ),
            ],
          ],
      ),
    );
  }
}
