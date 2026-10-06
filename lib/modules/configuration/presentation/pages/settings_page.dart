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
    appBar: AppBar(
      title: Semantics(header: true, child: const Text('Configuración')),
    ),
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
              : 'La transición a producción y la purga de datos están bloqueadas hasta implementar y verificar el acceso con Supabase Auth.',
        ),
        if (widget.initial.appMode == 'TEST') ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Acción bloqueada. Las cuentas se aprovisionarán '
                        'sin registro abierto; el primer superadministrador '
                        'debe vincularse mediante Supabase Auth.',
                      ),
                    ),
                  ],
                ),
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
          'Define el nombre y las unidades que contiene cada presentación. Ejemplo: Caja + 6 unidades. Ese factor guía el incremento de cantidad al cotizar.',
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Tipos de identificación',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _editIdentificationType(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo tipo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Gestiona los tipos que se usan en el formulario de cliente y en los '
          'datos fiscales. Desactivar un tipo impide asignarlo a clientes '
          'nuevos; los clientes que ya lo usan lo conservan.',
        ),
        const SizedBox(height: 16),
        ref
            .watch(identificationTypesAdminDtosProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('No se pudieron cargar: $error'),
              data: (items) {
                if (items.isEmpty) {
                  return const Text('No hay tipos de identificación.');
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in items)
                      ActionChip(
                        avatar: Icon(
                          item.isActive ? Icons.badge_outlined : Icons.block,
                          size: 18,
                        ),
                        label: Text(
                          item.isActive ? item.name : '${item.name} (inactivo)',
                        ),
                        tooltip: 'Editar tipo de identificación',
                        onPressed: () => _editIdentificationType(item),
                      ),
                  ],
                );
              },
            ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Categorías comerciales de clientes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _editCustomerCategory(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva categoría'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Organiza los clientes por segmentos comerciales (ej. Mayorista, '
          'Detallista, Distribuidor). Puedes asignarles un color para identificarlos fácilmente.',
        ),
        const SizedBox(height: 16),
        ref
            .watch(customerCategoriesAdminDtosProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('No se pudieron cargar: $error'),
              data: (items) {
                if (items.isEmpty) {
                  return const Text(
                    'No hay categorías comerciales registradas.',
                  );
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in items)
                      ActionChip(
                        avatar:
                            item.color != null &&
                                _tryParseColor(item.color) != null
                            ? CircleAvatar(
                                radius: 8,
                                backgroundColor: _tryParseColor(item.color),
                              )
                            : Icon(
                                item.isActive
                                    ? Icons.label_outline
                                    : Icons.label_off_outlined,
                                size: 18,
                              ),
                        label: Text(
                          item.isActive ? item.name : '${item.name} (inactiva)',
                        ),
                        tooltip: 'Editar categoría comercial',
                        onPressed: () => _editCustomerCategory(item),
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
                        '${item.name} · ${item.unitsPerPresentation} ${item.unitsPerPresentation == 1 ? 'unidad' : 'unidades'}',
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
    final unitsController = TextEditingController(
      text: '${existing?.unitsPerPresentation ?? 1}',
    );
    String? nameError;
    String? unitsError;
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
            final units = int.tryParse(unitsController.text.trim());
            if (units == null || units < 1) {
              setDialogState(
                () =>
                    unitsError = 'Ingrese una cantidad entera mayor que cero.',
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
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        hintText: 'Ej. Caja',
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: unitsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Unidades por presentación',
                        hintText: 'Ej. 6',
                        errorText: unitsError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        markDirty();
                        if (unitsError != null) {
                          setDialogState(() => unitsError = null);
                        }
                      },
                      onSubmitted: (_) => submit(),
                    ),
                  ],
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
    if (accepted == true) {
      final api = ref.read(configurationApiProvider);
      final identity = ref.read(identityContextProvider);
      if (existing == null) {
        await api.createPackagingPresentation(
          CreatePackagingPresentationCommand(
            commandId: const Uuid().v4(),
            name: controller.text,
            unitsPerPresentation: int.parse(unitsController.text.trim()),
            identity: identity,
          ),
        );
      } else {
        await api.updatePackagingPresentation(
          UpdatePackagingPresentationCommand(
            id: existing.id,
            name: controller.text,
            unitsPerPresentation: int.parse(unitsController.text.trim()),
            expectedVersion: existing.version,
            identity: identity,
          ),
        );
      }
      ref.invalidate(packagingPresentationDtosProvider);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
      unitsController.dispose();
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

  Future<void> _editIdentificationType([
    IdentificationTypeDto? existing,
  ]) async {
    final code = TextEditingController();
    final name = TextEditingController(text: existing?.name ?? '');
    String? codeError;
    String? nameError;
    var isActive = existing?.isActive ?? true;
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
            var invalid = false;
            if (existing == null && code.text.trim().isEmpty) {
              setDialogState(() => codeError = 'Escriba el código del tipo.');
              invalid = true;
            }
            if (name.text.trim().isEmpty) {
              setDialogState(() => nameError = 'Escriba el nombre del tipo.');
              invalid = true;
            }
            if (invalid) return;
            final api = ref.read(configurationApiProvider);
            final identity = ref.read(identityContextProvider);
            try {
              if (existing == null) {
                await api.createIdentificationType(
                  CreateIdentificationTypeCommand(
                    commandId: const Uuid().v4(),
                    code: code.text.trim().toUpperCase(),
                    name: name.text.trim(),
                    identity: identity,
                  ),
                );
              } else {
                await api.updateIdentificationType(
                  UpdateIdentificationTypeCommand(
                    id: existing.id,
                    name: name.text.trim(),
                    isActive: isActive,
                    expectedVersion: existing.version,
                    identity: identity,
                  ),
                );
              }
              if (context.mounted) Navigator.pop(context, true);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No fue posible guardar: '
                      '${_friendlyConfigurationError(error)}',
                    ),
                  ),
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
                existing == null
                    ? 'Nuevo tipo de identificación'
                    : 'Editar tipo de identificación',
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (existing == null) ...[
                        TextField(
                          controller: code,
                          autofocus: true,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Código',
                            hintText: 'PHYSICAL_ID',
                            errorText: codeError,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            markDirty();
                            if (codeError != null) {
                              setDialogState(() => codeError = null);
                            }
                          },
                          onSubmitted: (_) => submit(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: name,
                        autofocus: existing != null,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Cédula física',
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
                      if (existing != null) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Activo'),
                          subtitle: const Text(
                            'Los tipos inactivos no se pueden asignar a '
                            'clientes nuevos.',
                          ),
                          value: isActive,
                          onChanged: (value) {
                            markDirty();
                            setDialogState(() => isActive = value);
                          },
                        ),
                      ],
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
      code.dispose();
      name.dispose();
    });
    if (accepted == true) {
      ref.invalidate(identificationTypesAdminDtosProvider);
      ref.invalidate(identificationTypeDtosProvider);
    }
  }

  Future<void> _editCustomerCategory([CustomerCategoryDto? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    String? selectedColor = existing?.color;
    String? nameError;
    var isActive = existing?.isActive ?? true;
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
                () => nameError = 'Escriba el nombre de la categoría.',
              );
              return;
            }
            final api = ref.read(configurationApiProvider);
            try {
              if (existing == null) {
                await api.createCustomerCategory(
                  CreateCustomerCategoryCommand(
                    name: name.text.trim(),
                    description: _optional(description.text),
                    color: selectedColor,
                  ),
                );
              } else {
                await api.updateCustomerCategory(
                  UpdateCustomerCategoryCommand(
                    id: existing.id,
                    name: name.text.trim(),
                    description: _optional(description.text),
                    color: selectedColor,
                    isActive: isActive,
                  ),
                );
              }
              if (context.mounted) Navigator.pop(context, true);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No fue posible guardar: '
                      '${_friendlyConfigurationError(error)}',
                    ),
                  ),
                );
              }
            }
          }

          Future<void> deleteCategory() async {
            if (existing == null) return;
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Eliminar categoría comercial'),
                content: Text(
                  '¿Desea eliminar la categoría "${existing.name}"? '
                  'Si ya está asociada a clientes, deberá desactivarla en su lugar.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                      foregroundColor: Theme.of(ctx).colorScheme.onError,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => Navigator.pop(ctx, true),
                    label: const Text('Eliminar'),
                  ),
                ],
              ),
            );
            if (confirm != true || !context.mounted) return;
            try {
              await ref
                  .read(configurationApiProvider)
                  .deleteCustomerCategory(
                    DeleteCustomerCategoryCommand(id: existing.id),
                  );
              if (context.mounted) Navigator.pop(context, true);
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No fue posible eliminar la categoría: '
                      '${_friendlyConfigurationError(error)}',
                    ),
                  ),
                );
              }
            }
          }

          const colorPresets = [
            '#1E88E5',
            '#43A047',
            '#FB8C00',
            '#E53935',
            '#8E24AA',
            '#00ACC1',
            '#3949AB',
            '#D81B60',
            '#546E7A',
          ];

          return PopScope(
            canPop: !dirty,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await cancel();
            },
            child: AlertDialog(
              title: Text(
                existing == null
                    ? 'Nueva categoría comercial'
                    : 'Editar categoría comercial',
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: name,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Nombre *',
                          hintText: 'Mayorista, Detallista, etc.',
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
                        controller: description,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          hintText: 'Criterios de asignación o notas',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => markDirty(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Color identificativo',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ChoiceChip(
                            label: const Text('Ninguno'),
                            selected: selectedColor == null,
                            onSelected: (selected) {
                              if (selected) {
                                markDirty();
                                setDialogState(() => selectedColor = null);
                              }
                            },
                          ),
                          for (final hex in colorPresets)
                            GestureDetector(
                              onTap: () {
                                markDirty();
                                setDialogState(() => selectedColor = hex);
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _tryParseColor(hex),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selectedColor == hex
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: selectedColor == hex ? 3 : 1,
                                  ),
                                ),
                                child: selectedColor == hex
                                    ? const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                        ],
                      ),
                      if (existing != null) ...[
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Activa'),
                          subtitle: const Text(
                            'Las categorías inactivas no se muestran para seleccionar en clientes nuevos.',
                          ),
                          value: isActive,
                          onChanged: (value) {
                            markDirty();
                            setDialogState(() => isActive = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .error,
                            ),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Eliminar categoría'),
                            onPressed: deleteCategory,
                          ),
                        ),
                      ],
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
      description.dispose();
    });
    if (accepted == true) {
      ref.invalidate(customerCategoriesAdminDtosProvider);
      ref.invalidate(customerCategoriesDtosProvider);
    }
  }

  Color? _tryParseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      final value = int.tryParse('FF$clean', radix: 16);
      if (value != null) return Color(value);
    }
    return null;
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
    if (text.contains('CATEGORY_IN_USE')) {
      return 'la categoría está asignada a uno o más clientes. Desactívala en su lugar para no afectar el historial.';
    }
    if (text.contains('VERSION_CONFLICT')) {
      return 'el registro fue modificado en otra ventana. Recarga e intenta de nuevo.';
    }
    if (text.contains('NOT_FOUND')) {
      return 'el registro ya no existe o ya fue desactivado.';
    }
    return text;
  }
}
