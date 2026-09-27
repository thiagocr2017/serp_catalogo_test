import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProductFormPage extends StatelessWidget {
  const ProductFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/products'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Nuevo producto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Información general',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'SKU',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Código de barras',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const TextField(
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Precios y empaque',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Precio unitario (USD)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Precio por paquete (USD)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'MOQ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'CBM por MOQ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Costo de fábrica',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'La selección de categoría y el guardado se habilitarán al implementar el catálogo de categorías.',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context.go('/products'),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    const FilledButton(
                      onPressed: null,
                      child: Text('Guardar producto'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
