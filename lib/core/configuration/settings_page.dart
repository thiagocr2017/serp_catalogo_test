import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_settings.dart';
import 'settings_providers.dart';

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
          ),
        );
    ref.invalidate(businessSettingsProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuración guardada')));
    }
  }
}
