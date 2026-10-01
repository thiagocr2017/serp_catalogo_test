import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/quote_api.dart';
import '../../../../shared/widgets/status_chip.dart';

class QuotesPage extends ConsumerWidget {
  const QuotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(quotesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cotizaciones')),
      body: quotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (quotes) {
          if (quotes.isEmpty) {
            return const Center(
              child: Text('No hay cotizaciones registradas.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: quotes.length,
            itemBuilder: (context, index) {
              final quote = quotes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(quote.quoteNumber),
                  subtitle: Text(quote.customerName),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${quote.totalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      StatusChip(
                        label: switch (quote.status) {
                          QuoteStatus.draft => 'Borrador',
                          QuoteStatus.sent => 'Enviada',
                          QuoteStatus.accepted => 'Aceptada',
                          QuoteStatus.rejected => 'Rechazada',
                          QuoteStatus.expired => 'Expirada',
                          QuoteStatus.converted => 'Convertida',
                        },
                        tone: switch (quote.status) {
                          QuoteStatus.accepted => StatusTone.success,
                          QuoteStatus.rejected => StatusTone.danger,
                          QuoteStatus.expired => StatusTone.warning,
                          QuoteStatus.converted => StatusTone.info,
                          _ => StatusTone.neutral,
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
