import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/product_list_controller.dart';

class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(productListControllerProvider.notifier).refresh(),
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No fue posible cargar los productos.\n$error'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No hay productos registrados.'))
            : ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final product = items[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(product.sku[0])),
                      title: Text(product.name),
                      subtitle: Text(
                        '${product.sku} · Stock: ${product.currentStock} · '
                        'MOQ: ${product.minimumOrderQuantity}',
                      ),
                      trailing: Text(
                        '\$${(product.unitPriceInCents / 100).toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
