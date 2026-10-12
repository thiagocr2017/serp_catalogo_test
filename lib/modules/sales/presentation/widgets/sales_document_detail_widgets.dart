import 'package:flutter/material.dart';

import '../../../../shared/widgets/status_chip.dart';

class SalesDocumentHeader extends StatelessWidget {
  const SalesDocumentHeader({
    required this.number,
    required this.status,
    required this.statusTone,
    this.facts = const [],
    this.numberStyle,
    super.key,
  });

  final String number;
  final String status;
  final StatusTone statusTone;
  final List<String> facts;
  final TextStyle? numberStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  number,
                  style: numberStyle ?? theme.textTheme.headlineSmall,
                ),
                StatusChip(label: status, tone: statusTone),
              ],
            ),
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  for (final fact in facts)
                    Text(fact, style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SalesDocumentSectionTitle extends StatelessWidget {
  const SalesDocumentSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class SalesDocumentLineCard extends StatelessWidget {
  const SalesDocumentLineCard({
    required this.productName,
    required this.productSku,
    required this.quantityLabel,
    required this.unitPrice,
    required this.currencyCode,
    required this.total,
    this.discountPercent,
    this.additionalDetails,
    super.key,
  });

  final String productName;
  final String? productSku;
  final String quantityLabel;
  final double unitPrice;
  final String currencyCode;
  final double total;
  final double? discountPercent;
  final String? additionalDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(productName, style: theme.textTheme.titleSmall),
                      if (productSku?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text('SKU ${productSku!.trim()}'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    '$currencyCode ${total.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Text(quantityLabel),
                Text(
                  'Precio unitario: $currencyCode ${unitPrice.toStringAsFixed(2)}',
                ),
                if (discountPercent != null)
                  Text('Descuento: ${discountPercent!.toStringAsFixed(2)}%'),
                if (additionalDetails?.trim().isNotEmpty == true)
                  Text(additionalDetails!.trim()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SalesDocumentTotalCard extends StatelessWidget {
  const SalesDocumentTotalCard({
    required this.amount,
    required this.currencyCode,
    this.label = 'Total del documento',
    this.additionalAmounts = const {},
    super.key,
  });

  final double amount;
  final String currencyCode;
  final String label;
  final Map<String, double> additionalAmounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in additionalAmounts.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    Text('$currencyCode ${entry.value.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            if (additionalAmounts.isNotEmpty) const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(label, style: theme.textTheme.titleMedium),
                ),
                Text(
                  '$currencyCode ${amount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
