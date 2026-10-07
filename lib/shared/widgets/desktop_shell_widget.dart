import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/unsaved_changes_guard.dart';

class DesktopShellWidget extends StatelessWidget {
  const DesktopShellWidget({
    required this.currentLocation,
    required this.child,
    super.key,
  });

  final String currentLocation;
  final Widget child;

  bool _selected(String path) => currentLocation.startsWith(path);
  bool _moduleSelected(List<String> routes) => routes.any(_selected);

  @override
  Widget build(BuildContext context) {
    final productModuleSelected = _moduleSelected(const [
      '/products',
      '/categories',
      '/promotions',
      '/catalog-export',
      '/product-transfer',
    ]);
    final salesModuleSelected = _moduleSelected(const [
      '/sales/agents',
      '/sales/customers',
      '/sales/quotes',
      '/sales/orders',
      '/sales/invoices',
      '/sales/returns',
      '/sales/consignments',
    ]);
    final inventoryModuleSelected = _selected('/inventory');
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
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icon/SERP_logo_v2.png',
                        height: 64,
                        semanticLabel: 'Logo de SERP',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ExpansionTile(
                    initiallyExpanded: productModuleSelected,
                    splashColor: Colors.transparent,
                    enableFeedback: false,
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
                  ExpansionTile(
                    initiallyExpanded: salesModuleSelected,
                    splashColor: Colors.transparent,
                    enableFeedback: false,
                    leading: const Icon(Icons.point_of_sale_outlined),
                    title: const Text('Ventas'),
                    childrenPadding: const EdgeInsets.only(left: 16),
                    children: [
                      _item(
                        context,
                        '/sales/agents',
                        'Agentes',
                        Icons.badge_outlined,
                      ),
                      _item(
                        context,
                        '/sales/customers',
                        'Clientes',
                        Icons.groups_outlined,
                      ),
                      _item(
                        context,
                        '/sales/quotes',
                        'Cotizaciones',
                        Icons.request_quote_outlined,
                      ),
                      _item(
                        context,
                        '/sales/orders',
                        'Pedidos',
                        Icons.shopping_bag_outlined,
                      ),
                      _item(
                        context,
                        '/sales/invoices',
                        'Facturas',
                        Icons.receipt_long_outlined,
                      ),
                      _item(
                        context,
                        '/sales/returns',
                        'Devoluciones',
                        Icons.assignment_return_outlined,
                      ),
                      _item(
                        context,
                        '/sales/consignments',
                        'Consignaciones',
                        Icons.inventory_2_outlined,
                      ),
                    ],
                  ),
                  ExpansionTile(
                    initiallyExpanded: inventoryModuleSelected,
                    splashColor: Colors.transparent,
                    enableFeedback: false,
                    leading: const Icon(Icons.swap_vert_circle_outlined),
                    title: const Text('Inventario'),
                    childrenPadding: const EdgeInsets.only(left: 16),
                    children: [
                      _item(
                        context,
                        '/inventory',
                        'Movimientos',
                        Icons.swap_vert_outlined,
                        exact: true,
                      ),
                      _item(
                        context,
                        '/inventory/warehouses',
                        'Bodegas y ubicaciones',
                        Icons.warehouse_outlined,
                      ),
                    ],
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
    IconData icon, {
    bool exact = false,
  }) => ListTile(
    dense: true,
    selected: exact ? currentLocation == path : _selected(path),
    selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    leading: Icon(icon),
    title: Text(label),
    onTap: () async {
      if (currentLocation == path) return;
      if (!await UnsavedChangesGuard.instance.confirmNavigation(context)) {
        return;
      }
      if (context.mounted) context.go(path);
    },
  );
}
