import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DesktopShellWidget extends StatelessWidget {
  const DesktopShellWidget({
    required this.currentLocation,
    required this.child,
    super.key,
  });

  final String currentLocation;
  final Widget child;

  bool _selected(String path) => currentLocation.startsWith(path);

  @override
  Widget build(BuildContext context) {
    final productModuleSelected = const [
      '/products',
      '/categories',
      '/promotions',
      '/catalog-export',
      '/product-transfer',
    ].any(_selected);
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 245,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 24,
                      child: Text(
                        'S',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ExpansionTile(
                    initiallyExpanded: productModuleSelected,
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Productos'),
                    childrenPadding: const EdgeInsets.only(left: 16),
                    children: [
                      _item(
                        context,
                        '/products',
                        'Lista de productos',
                        Icons.list_alt_outlined,
                      ),
                      _item(
                        context,
                        '/categories',
                        'Categorías',
                        Icons.category_outlined,
                      ),
                      _item(
                        context,
                        '/promotions',
                        'Promociones',
                        Icons.sell_outlined,
                      ),
                      _item(
                        context,
                        '/catalog-export',
                        'Catálogo PDF',
                        Icons.picture_as_pdf_outlined,
                      ),
                      _item(
                        context,
                        '/product-transfer',
                        'Importar / Exportar',
                        Icons.import_export_outlined,
                      ),
                    ],
                  ),
                  _item(
                    context,
                    '/inventory',
                    'Inventario',
                    Icons.swap_vert_circle_outlined,
                  ),
                  _item(context, '/audit', 'Auditoría', Icons.history_outlined),
                  _item(
                    context,
                    '/settings',
                    'Configuración',
                    Icons.settings_outlined,
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String path,
    String label,
    IconData icon,
  ) => ListTile(
    dense: true,
    selected: _selected(path),
    selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    leading: Icon(icon),
    title: Text(label),
    onTap: () => context.go(path),
  );
}
