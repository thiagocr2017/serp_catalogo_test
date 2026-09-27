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

  static const _destinations = [
    _Destination('/products', 'Productos', Icons.inventory_2_outlined),
    _Destination('/categories', 'Categorías', Icons.category_outlined),
    _Destination('/inventory', 'Inventario', Icons.swap_vert_circle_outlined),
    _Destination('/audit', 'Auditoría', Icons.history_outlined),
    _Destination('/promotions', 'Promociones', Icons.sell_outlined),
    _Destination(
      '/catalog-export',
      'Catálogo PDF',
      Icons.picture_as_pdf_outlined,
    ),
    _Destination('/settings', 'Configuración', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _destinations.indexWhere(
      (destination) => currentLocation.startsWith(destination.path),
    );

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1100,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (index) =>
                context.go(_destinations[index].path),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircleAvatar(
                radius: 24,
                child: Text('S', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            destinations: [
              for (final destination in _destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}
