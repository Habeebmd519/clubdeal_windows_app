import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/stock_bloc.dart';

// import '../../core/models/stock_model.dart';

class AddStockForm extends StatefulWidget {
  const AddStockForm({super.key});
  @override
  State<AddStockForm> createState() => _AddStockFormState();
}

class _AddStockFormState extends State<AddStockForm> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(),
      category = TextEditingController(),
      unit = TextEditingController(text: 'pcs');
  final quantity = TextEditingController(text: '0'),
      threshold = TextEditingController(text: '5'),
      cost = TextEditingController(text: '0');

  @override
  void dispose() {
    name.dispose();
    category.dispose();
    unit.dispose();
    quantity.dispose();
    threshold.dispose();
    cost.dispose();
    super.dispose();
  }

  double number(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add Stock Item'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(name, 'Item name', required: true),
              _field(category, 'Category'),
              _field(unit, 'Unit (kg, litre, pcs)', required: true),
              _field(quantity, 'Opening quantity', numeric: true),
              _field(threshold, 'Low-stock threshold', numeric: true),
              _field(cost, 'Unit cost (₹)', numeric: true),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          context.read<StockBloc>().add(
            CreateStock(
              name: name.text,
              category: category.text,
              unit: unit.text,
              openingQuantity: number(quantity),
              lowStockThreshold: number(threshold),
              unitCost: number(cost),
            ),
          );
          Navigator.pop(context);
        },
        child: const Text('Save Stock'),
      ),
    ],
  );
}

class PurchaseStockForm extends StatefulWidget {
  const PurchaseStockForm({super.key});

  @override
  State<PurchaseStockForm> createState() => _PurchaseStockFormState();
}

class _PurchaseStockFormState extends State<PurchaseStockForm> {
  String? stockId;
  bool submitting = false;

  final qty = TextEditingController();
  final price = TextEditingController();
  final supplier = TextEditingController();
  final note = TextEditingController();

  final formKey = GlobalKey<FormState>();

  double number(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  void dispose() {
    qty.dispose();
    price.dispose();
    supplier.dispose();
    note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;

    if (stockId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a stock item.')),
      );
      return;
    }

    setState(() => submitting = true);

    context.read<StockBloc>().add(
      PurchaseStock(
        stockId: stockId!,
        quantity: number(qty),
        unitPrice: number(price),
        supplier: supplier.text.trim(),
        note: note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StockBloc, StockState>(
      listenWhen: (previous, current) =>
          current.error != null ||
          current.transactions.length > previous.transactions.length,
      listener: (context, state) {
        if (state.error != null) {
          setState(() => submitting = false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase failed: ${state.error}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (state.transactions.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stock purchase recorded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      },
      child: AlertDialog(
        title: const Text('Purchase Stock'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: stockId,
                  decoration: const InputDecoration(labelText: 'Stock item'),
                  items: context.watch<StockBloc>().state.items.map((s) {
                    return DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.name} (${s.quantity} ${s.unit})'),
                    );
                  }).toList(),
                  onChanged: submitting
                      ? null
                      : (value) => setState(() => stockId = value),
                  validator: (value) =>
                      value == null ? 'Select a stock item' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: qty,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Purchased quantity',
                  ),
                  validator: (value) {
                    final n = double.tryParse(value ?? '');
                    return n == null || n <= 0
                        ? 'Enter a quantity above zero'
                        : null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Unit purchase price (₹)',
                  ),
                  validator: (value) {
                    final n = double.tryParse(value ?? '');
                    return n == null || n < 0 ? 'Enter a valid price' : null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: supplier,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Note / invoice reference',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: submitting ? null : _submit,
            icon: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(submitting ? 'Saving...' : 'Add Purchase'),
          ),
        ],
      ),
    );
  }
}

class UseStockForm extends StatefulWidget {
  const UseStockForm({super.key});
  @override
  State<UseStockForm> createState() => _UseStockFormState();
}

class _UseStockFormState extends State<UseStockForm> {
  String? stockId;
  final qty = TextEditingController(), note = TextEditingController();
  double number(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  void dispose() {
    qty.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stocks = context.watch<StockBloc>().state.items;
    final selected = stocks.where((e) => e.id == stockId).firstOrNull;
    return AlertDialog(
      title: const Text('Record Stock Usage'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: stockId,
              decoration: const InputDecoration(labelText: 'Stock item'),
              items: stocks
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.name} (${s.quantity} ${s.unit})'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => stockId = v),
            ),
            if (selected != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Available: ${selected.quantity} ${selected.unit}',
                  ),
                ),
              ),
            _field(qty, 'Quantity used', numeric: true),
            _field(note, 'Reason / notes'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: stockId == null || number(qty) <= 0
              ? null
              : () {
                  context.read<StockBloc>().add(
                    UseStock(
                      stockId: stockId!,
                      quantity: number(qty),
                      note: note.text,
                    ),
                  );
                  Navigator.pop(context);
                },
          child: const Text('Save Usage'),
        ),
      ],
    );
  }
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool numeric = false,
  bool required = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextFormField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
          : null,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
