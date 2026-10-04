import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/configuration/theme_mode_controller.dart';
import '../../../../core/identity/identity_context_provider.dart';
import '../../../../shared/navigation/unsaved_changes_guard.dart';
import '../../api/configuration_api.dart';
import '../../di/configuration_providers.dart';
import '../../domain/entities/business_settings.dart';

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
          data: (value) => ref
              .watch(businessSettingsDtoProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (dto) => _SettingsForm(
                  initial: value,
                  initialBusinessVersion: dto.version,
                ),
              ),
        ),
  );
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({
    required this.initial,
    required this.initialBusinessVersion,
  });
  final BusinessSettings initial;
  final int initialBusinessVersion;
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
  late int businessVersion = widget.initialBusinessVersion;
  Uint8List? catalogLogo;
  int catalogLogoVersion = 1;
  bool loadingLogo = true;
  bool dirty = false;

  @override
  void initState() {
    super.initState();
    company.addListener(_markDirty);
    payments.addListener(_markDirty);
    tax.addListener(_markDirty);
    increment.addListener(_markDirty);
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    final api = ref.read(configurationApiProvider);
    final preferences = await api.getCatalogPreferences();
    final bytes = await api.downloadCatalogLogo();
    if (mounted) {
      setState(() {
        catalogLogo = bytes;
        catalogLogoVersion = preferences.logoVersion;
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
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final navigator = Navigator.of(context);
      if (await UnsavedChangesGuard.instance.confirmNavigation(context) &&
          mounted) {
        _markClean();
        navigator.pop();
      }
    },
    child: ListView(
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
                widget.initial.appMode == 'PRODUCTION'
                    ? 'Producción'
                    : 'Prueba',
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
        if (widget.initial.appMode == 'TEST' &&
            widget.initial.isSuperAdmin) ...[
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
              label: const Text(
                'Eliminar datos de prueba y pasar a producción',
              ),
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
          'Crea los tipos necesarios, por ejemplo Unidad, Caja, Cartón, Paquete o Set. Puedes renombrarlos o desactivar los que ya no deban usarse en productos nuevos.',
        ),
        const SizedBox(height: 16),
        ref
            .watch(packagingPresentationDtosProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('No se pudieron cargar: $error'),
              data: _presentationList,
            ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Transportes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _editCarrier(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo transporte'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Gestiona los transportes que luego se seleccionan como preferencia del cliente y como transporte del pedido o factura.',
        ),
        const SizedBox(height: 16),
        ref
            .watch(carrierDtosProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('No se pudieron cargar: $error'),
              data: (items) {
                if (items.isEmpty) {
                  return const Text('No hay transportes registrados.');
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in items)
                      ActionChip(
                        avatar: const Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                        ),
                        label: Text(item.name),
                        tooltip: 'Editar transporte',
                        onPressed: () => _editCarrier(item),
                      ),
                  ],
                );
              },
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
                onChanged: (v) => setState(() {
                  currency = v!;
                  _markDirty();
                }),
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
                onChanged: (v) => setState(() {
                  decimals = v!;
                  _markDirty();
                }),
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
                onChanged: (v) => setState(() {
                  rounding = v!;
                  _markDirty();
                }),
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
                onChanged: (v) => setState(() {
                  includesTax = v;
                  _markDirty();
                }),
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
    ),
  );

  Widget _presentationList(List<PackagingPresentationDto> items) {
    if (items.isEmpty) {
      return const Text('No hay presentaciones activas.');
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items)
          SizedBox(
            width: 260,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar presentación',
                      onPressed: () => _editPresentation(item),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Desactivar presentación',
                      onPressed: () => _deactivatePresentation(item),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _markDirty() {
    dirty = true;
    UnsavedChangesGuard.instance.markDirty();
  }

  void _markClean() {
    dirty = false;
    UnsavedChangesGuard.instance.markClean();
  }

  Future<void> _save() async {
    try {
      final saved = await ref
          .read(configurationApiProvider)
          .saveBusinessSettings(
            SaveBusinessSettingsCommand(
              defaultCurrency: currency,
              decimalPlaces: decimals,
              taxPercentage: tax.text.trim(),
              pricesIncludeTax: includesTax,
              roundingMode: rounding,
              roundingIncrement: increment.text.trim(),
              companyName: company.text.trim(),
              paymentMethods: payments.text.trim(),
              expectedVersion: businessVersion,
              identity: ref.read(identityContextProvider),
            ),
          );
      businessVersion = saved.version;
      _markClean();
      ref.invalidate(businessSettingsProvider);
      ref.invalidate(businessSettingsDtoProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Configuración guardada')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No fue posible guardar: $error')),
        );
      }
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
    final extension = file.name.split('.').last.toLowerCase();
    final mimeType = extension == 'png'
        ? 'image/png'
        : extension == 'webp'
        ? 'image/webp'
        : 'image/jpeg';
    final saved = await ref
        .read(configurationApiProvider)
        .replaceCatalogLogo(
          ReplaceCatalogLogoCommand(
            operationId: const Uuid().v4(),
            bytes: bytes,
            mimeType: mimeType,
            expectedVersion: catalogLogoVersion,
            identity: ref.read(identityContextProvider),
          ),
        );
    if (mounted) {
      setState(() {
        catalogLogo = bytes;
        catalogLogoVersion = saved.version;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo guardado correctamente.')),
      );
    }
  }

  Future<void> _editPresentation([PackagingPresentationDto? existing]) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    String? nameError;
    var dirty = false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void markDirty() {
            if (dirty) return;
            setDialogState(() => dirty = true);
          }

          Future<void> cancel() async {
            final navigator = Navigator.of(context);
            final discard = await UnsavedChangesGuard.instance.confirmDiscard(
              context,
              hasUnsavedChanges: dirty,
            );
            if (discard && context.mounted) navigator.pop(false);
          }

          void submit() {
            if (controller.text.trim().isEmpty) {
              setDialogState(
                () => nameError = 'Escriba el nombre de la presentación.',
              );
              return;
            }
            Navigator.pop(context, true);
          }

          return PopScope(
            canPop: !dirty,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await cancel();
            },
            child: AlertDialog(
              title: Text(
                existing == null ? 'Nueva presentación' : 'Editar presentación',
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Cartón',
                  errorText: nameError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  markDirty();
                  if (nameError != null) {
                    setDialogState(() => nameError = null);
                  }
                },
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(onPressed: cancel, child: const Text('Cancelar')),
                FilledButton(onPressed: submit, child: const Text('Guardar')),
              ],
            ),
          );
        },
      ),
    );
    if (accepted == true) {
      final api = ref.read(configurationApiProvider);
      final identity = ref.read(identityContextProvider);
      if (existing == null) {
        await api.createPackagingPresentation(
          CreatePackagingPresentationCommand(
            commandId: const Uuid().v4(),
            name: controller.text,
            identity: identity,
          ),
        );
      } else {
        await api.updatePackagingPresentation(
          UpdatePackagingPresentationCommand(
            id: existing.id,
            name: controller.text,
            expectedVersion: existing.version,
            identity: identity,
          ),
        );
      }
      ref.invalidate(packagingPresentationDtosProvider);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  Future<void> _deactivatePresentation(PackagingPresentationDto item) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar presentación'),
        content: Text(
          '¿Deseas desactivar "${item.name}"? Ya no aparecerá al crear productos nuevos. Si algún producto la usa, la aplicación no permitirá desactivarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await ref
          .read(configurationApiProvider)
          .deactivatePackagingPresentation(
            DeactivatePackagingPresentationCommand(
              id: item.id,
              expectedVersion: item.version,
              identity: ref.read(identityContextProvider),
            ),
          );
      ref.invalidate(packagingPresentationDtosProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${item.name}" fue desactivada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No fue posible desactivar la presentación: ${_friendlyConfigurationError(error)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _editCarrier([CarrierDto? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final contactName = TextEditingController(
      text: existing?.contactName ?? '',
    );
    final notes = TextEditingController(text: existing?.notes ?? '');
    String? nameError;
    var dirty = false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void markDirty() {
            if (dirty) return;
            setDialogState(() => dirty = true);
          }

          Future<void> cancel() async {
            final navigator = Navigator.of(context);
            final discard = await UnsavedChangesGuard.instance.confirmDiscard(
              context,
              hasUnsavedChanges: dirty,
            );
            if (discard && context.mounted) navigator.pop(false);
          }

          Future<void> submit() async {
            if (name.text.trim().isEmpty) {
              setDialogState(
                () => nameError = 'Escriba el nombre del transporte.',
              );
              return;
            }
            final api = ref.read(configurationApiProvider);
            final identity = ref.read(identityContextProvider);
            try {
              await api.saveCarrier(
                SaveCarrierCommand(
                  id: existing?.id,
                  commandId: const Uuid().v4(),
                  name: name.text.trim(),
                  phone: _optional(phone.text),
                  address: _optional(address.text),
                  contactName: _optional(contactName.text),
                  notes: _optional(notes.text),
                  expectedVersion: existing?.version,
                  identity: identity,
                ),
              );
              if (context.mounted) Navigator.pop(context, true);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No fue posible guardar: $error')),
                );
              }
            }
          }

          return PopScope(
            canPop: !dirty,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await cancel();
            },
            child: AlertDialog(
              title: Text(
                existing == null ? 'Nuevo transporte' : 'Editar transporte',
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          errorText: nameError,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          markDirty();
                          if (nameError != null) {
                            setDialogState(() => nameError = null);
                          }
                        },
                        onSubmitted: (_) => submit(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => markDirty(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contactName,
                        decoration: const InputDecoration(
                          labelText: 'Contacto',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => markDirty(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: address,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => markDirty(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notas',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => markDirty(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: cancel, child: const Text('Cancelar')),
                FilledButton(onPressed: submit, child: const Text('Guardar')),
              ],
            ),
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      phone.dispose();
      address.dispose();
      contactName.dispose();
      notes.dispose();
    });
    if (accepted == true) {
      ref.invalidate(carrierDtosProvider);
    }
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _friendlyConfigurationError(Object error) {
    final text = error.toString();
    if (text.contains('PRESENTATION_IN_USE')) {
      return 'hay productos usando esta presentación. Cambia esos productos a otra presentación antes de desactivarla.';
    }
    if (text.contains('VERSION_CONFLICT')) {
      return 'la presentación fue modificada en otra ventana. Recarga e intenta de nuevo.';
    }
    if (text.contains('NOT_FOUND')) {
      return 'la presentación ya no existe o ya fue desactivada.';
    }
    return text;
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
    await ref
        .read(configurationRepositoryProvider)
        .purgeTestDataAndGoProduction();
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
