import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_settings.dart';
import 'packaging_presentation.dart';
import 'settings_providers.dart';
import 'theme_mode_controller.dart';

class _ThemeModeSection extends ConsumerWidget {
  const _ThemeModeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeModeProvider).value ?? ThemeMode.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Apariencia', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'El modo oscuro se utiliza inicialmente. Tu elección se conserva en este equipo.',
        ),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Oscuro'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Claro'),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (values) =>
              ref.read(themeModeProvider.notifier).setThemeMode(values.first),
        ),
      ],
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Configuración')),
    body: ref
        .watch(businessSettingsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (value) => _SettingsForm(initial: value),
        ),
  );
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial});
  final BusinessSettings initial;
  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final company = TextEditingController(text: widget.initial.companyName);
  late final payments = TextEditingController(
    text: widget.initial.paymentMethods,
  );
  late final tax = TextEditingController(
    text: widget.initial.taxPercentage.toStringAsFixed(2),
  );
  late final increment = TextEditingController(
    text: widget.initial.roundingIncrement.toStringAsFixed(2),
  );
  late String currency = widget.initial.defaultCurrency;
  late int decimals = widget.initial.decimalPlaces;
  late bool includesTax = widget.initial.pricesIncludeTax;
  late String rounding = widget.initial.roundingMode;
  Uint8List? catalogLogo;
  bool loadingLogo = true;

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final repository = ref.read(settingsRepositoryProvider);
    final preferences = await repository.getCatalogPreferences();
    final bytes = await repository.downloadCatalogLogo(preferences.logoUrl);
    if (mounted) {
      setState(() {
        catalogLogo = bytes;
        loadingLogo = false;
      });
    }
  }

  @override
  void dispose() {
    company.dispose();
    payments.dispose();
    tax.dispose();
    increment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      const _ThemeModeSection(),
      const SizedBox(height: 28),
      Text(
        'Empresa y documentos',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: company,
        decoration: const InputDecoration(
          labelText: 'Nombre de empresa',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: payments,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Métodos de pago',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Logo de la empresa',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Container(
            width: 150,
            height: 100,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: loadingLogo
                ? const Center(child: CircularProgressIndicator())
                : catalogLogo == null
                ? const Icon(Icons.business_outlined, size: 42)
                : Image.memory(catalogLogo!, fit: BoxFit.contain),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _selectLogo,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              catalogLogo == null ? 'Seleccionar logo' : 'Cambiar logo',
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Row(
        children: [
          Text(
            'Entorno de la aplicación',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(width: 12),
          Chip(
            avatar: Icon(
              widget.initial.appMode == 'PRODUCTION'
                  ? Icons.verified_outlined
                  : Icons.science_outlined,
            ),
            label: Text(
              widget.initial.appMode == 'PRODUCTION' ? 'Producción' : 'Prueba',
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        widget.initial.appMode == 'PRODUCTION'
            ? 'Los datos actuales pertenecen al entorno de producción.'
            : 'El entorno de prueba permite eliminar todos los datos operativos antes de iniciar producción.',
      ),
      if (widget.initial.appMode == 'TEST' && widget.initial.isSuperAdmin) ...[
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
            ),
            onPressed: _confirmProduction,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Eliminar datos de prueba y pasar a producción'),
          ),
        ),
      ],
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(
            child: Text(
              'Presentaciones de productos',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _editPresentation(),
            icon: const Icon(Icons.add),
            label: const Text('Nueva presentación'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Crea todos los tipos necesarios, por ejemplo Unidad, Caja, Cartón, Paquete o Set. Puedes cambiar sus nombres en cualquier momento.',
      ),
      const SizedBox(height: 16),
      ref
          .watch(packagingPresentationsProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('No se pudieron cargar: $error'),
            data: (items) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in items)
                  ActionChip(
                    avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text(item.name),
                    tooltip: 'Editar nombre',
                    onPressed: () => _editPresentation(item),
                  ),
              ],
            ),
          ),
      const SizedBox(height: 28),
      Text(
        'Precios e impuestos',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              initialValue: currency,
              decoration: const InputDecoration(labelText: 'Moneda'),
              items: const [
                DropdownMenuItem(value: 'USD', child: Text('USD - Dólar')),
                DropdownMenuItem(value: 'CRC', child: Text('CRC - Colón')),
              ],
              onChanged: (v) => setState(() => currency = v!),
            ),
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<int>(
              initialValue: decimals,
              decoration: const InputDecoration(labelText: 'Decimales'),
              items: const [0, 1, 2, 3, 4]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) => setState(() => decimals = v!),
            ),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: tax,
              decoration: const InputDecoration(
                labelText: 'Impuesto %',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              initialValue: rounding,
              decoration: const InputDecoration(labelText: 'Redondeo'),
              items: const [
                DropdownMenuItem(
                  value: 'HALF_UP',
                  child: Text('Al más cercano'),
                ),
                DropdownMenuItem(value: 'UP', child: Text('Hacia arriba')),
                DropdownMenuItem(value: 'DOWN', child: Text('Hacia abajo')),
              ],
              onChanged: (v) => setState(() => rounding = v!),
            ),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: increment,
              decoration: const InputDecoration(
                labelText: 'Incremento de redondeo',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(
            width: 260,
            child: SwitchListTile(
              value: includesTax,
              title: const Text('Precios incluyen impuesto'),
              onChanged: (v) => setState(() => includesTax = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('Guardar configuración'),
        ),
      ),
    ],
  );
  Future<void> _save() async {
    await ref
        .read(settingsRepositoryProvider)
        .save(
          BusinessSettings(
            defaultCurrency: currency,
            decimalPlaces: decimals,
            taxPercentage: double.parse(tax.text),
            pricesIncludeTax: includesTax,
            roundingMode: rounding,
            roundingIncrement: double.parse(increment.text),
            companyName: company.text.trim(),
            paymentMethods: payments.text.trim(),
            appMode: widget.initial.appMode,
            isSuperAdmin: widget.initial.isSuperAdmin,
          ),
        );
    ref.invalidate(businessSettingsProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuración guardada')));
    }
  }

  Future<void> _selectLogo() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Imágenes',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
        ),
      ],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final repository = ref.read(settingsRepositoryProvider);
    final url = await repository.uploadCatalogLogo(
      bytes,
      file.name.split('.').last,
    );
    await repository.setCatalogLogoUrl(url);
    if (mounted) {
      setState(() => catalogLogo = bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo guardado correctamente.')),
      );
    }
  }

  Future<void> _editPresentation([PackagingPresentation? existing]) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null ? 'Nueva presentación' : 'Editar presentación',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej. Cartón',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) =>
              Navigator.pop(context, controller.text.trim().isNotEmpty),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim().isNotEmpty),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await ref
          .read(settingsRepositoryProvider)
          .savePackagingPresentation(id: existing?.id, name: controller.text);
      ref.invalidate(packagingPresentationsProvider);
    }
    controller.dispose();
  }

  Future<void> _confirmProduction() async {
    final confirmation = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar todos los datos de prueba'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acción elimina productos, imágenes, categorías, promociones, movimientos de inventario y auditoría. Conserva únicamente la configuración y cambia la aplicación a producción.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmation,
              decoration: const InputDecoration(
                labelText: 'Escribe PRODUCCION para confirmar',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              confirmation.text.trim().toUpperCase() == 'PRODUCCION',
            ),
            child: const Text('Eliminar y pasar a producción'),
          ),
        ],
      ),
    );
    confirmation.dispose();
    if (accepted != true) return;
    await ref.read(settingsRepositoryProvider).purgeTestDataAndGoProduction();
    ref.invalidate(businessSettingsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos de prueba eliminados. Modo producción activo.'),
        ),
      );
    }
  }
}
