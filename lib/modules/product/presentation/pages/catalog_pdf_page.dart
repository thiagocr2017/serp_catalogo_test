import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../di/product_providers.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_query.dart';
import '../../services/catalog_pdf_service.dart';

class CatalogPdfPage extends ConsumerStatefulWidget {
  const CatalogPdfPage({super.key});
  @override
  ConsumerState<CatalogPdfPage> createState() => _CatalogPdfPageState();
}

class _CatalogPdfPageState extends ConsumerState<CatalogPdfPage> {
  final company = TextEditingController(text: 'SERP');
  final payments = TextEditingController(
    text: 'Transferencia bancaria, efectivo y tarjeta',
  );
  final agent = TextEditingController(text: 'Thiago Lopez');
  final phone = TextEditingController(text: '+506');
  int cards = 4;
  List<Product>? products;
  Map<String, String> categoryNames = const {};
  final selected = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ref.read(getProductsProvider)(
      const ProductQuery(isActive: true),
    );
    final categories = await ref.read(categoriesProvider.future);
    if (mounted) {
      final sharedSelection = ref.read(selectedProductIdsProvider);
      setState(() {
        products = data;
        categoryNames = {
          for (final category in categories) category.id: category.name,
        };
        selected.addAll(
          sharedSelection.isEmpty
              ? data.map((p) => p.id)
              : data
                    .where((p) => sharedSelection.contains(p.id))
                    .map((p) => p.id),
        );
      });
    }
  }

  @override
  void dispose() {
    company.dispose();
    payments.dispose();
    agent.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = products;
    return Scaffold(
      appBar: AppBar(title: const Text('Generar catálogo PDF')),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                SizedBox(
                  width: 360,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      TextField(
                        controller: company,
                        decoration: const InputDecoration(labelText: 'Empresa'),
                      ),
                      TextField(
                        controller: payments,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Métodos de pago',
                        ),
                      ),
                      TextField(
                        controller: agent,
                        decoration: const InputDecoration(labelText: 'Agente'),
                      ),
                      TextField(
                        controller: phone,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: cards,
                        decoration: const InputDecoration(
                          labelText: 'Tarjetas por página',
                        ),
                        items: const [0, 1, 2, 3, 4, 6]
                            .map(
                              (v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                  v == 0 ? 'Lista compacta' : '$v tarjetas',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => cards = v!),
                      ),
                      const Divider(height: 32),
                      CheckboxListTile(
                        value: selected.length == data.length,
                        title: const Text('Todos los productos'),
                        onChanged: (v) => setState(() {
                          selected.clear();
                          if (v == true) selected.addAll(data.map((p) => p.id));
                          ref
                              .read(selectedProductIdsProvider.notifier)
                              .replaceAll(selected);
                        }),
                      ),
                      for (final p in data)
                        CheckboxListTile(
                          value: selected.contains(p.id),
                          title: Text(p.name),
                          subtitle: Text(p.sku),
                          onChanged: (v) => setState(() {
                            v! ? selected.add(p.id) : selected.remove(p.id);
                            ref
                                .read(selectedProductIdsProvider.notifier)
                                .replaceAll(selected);
                          }),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: PdfPreview(
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    pdfFileName: 'catalogo_serp.pdf',
                    build: (_) => CatalogPdfService().generate(
                      data.where((p) => selected.contains(p.id)).toList(),
                      CatalogPdfOptions(
                        companyName: company.text,
                        paymentMethods: payments.text,
                        agentName: agent.text,
                        agentPhone: phone.text,
                        cardsPerPage: cards,
                        categoryNames: categoryNames,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
