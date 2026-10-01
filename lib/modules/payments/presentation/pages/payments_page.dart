import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/payment_api.dart';

class PaymentsPage extends ConsumerWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pagos y Recibos')),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (methods) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Métodos de pago',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (methods.isEmpty)
              const Text('No hay métodos de pago configurados.')
            else
              ...methods.map(
                (m) => ListTile(
                  leading: const Icon(Icons.payment),
                  title: Text(m.name),
                  trailing: m.isActive
                      ? const Chip(label: Text('Activo'))
                      : const Chip(label: Text('Inactivo')),
                ),
              ),
            const SizedBox(height: 32),
            Text(
              'Cuentas monetarias',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ref.watch(moneyAccountsProvider).when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (accounts) {
                if (accounts.isEmpty) {
                  return const Text('No hay cuentas monetarias configuradas.');
                }
                return Column(
                  children: accounts
                      .map(
                        (a) => ListTile(
                          leading: const Icon(Icons.account_balance),
                          title: Text(a.name),
                          subtitle: Text('${a.accountType} · ${a.currencyCode}'),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
