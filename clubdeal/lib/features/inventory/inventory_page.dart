import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// import 'package:intl/intl.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/repositories/inventory_repository.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final InventoryRepository _repository;
  StreamSubscription<List<Ingredient>>? _subscription;
  List<Ingredient> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = InventoryRepository(FirebaseFirestore.instance);
    _subscription = _repository.watchIngredients().listen(
      (items) {
        if (mounted)
          setState(() {
            _items = items;
            _loading = false;
            _error = null;
          });
      },
      onError: (Object e) {
        if (mounted)
          setState(() {
            _loading = false;
            _error = e.toString();
          });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Ingredient? _find(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _createIngredient() async {
    final name = TextEditingController();
    final unit = TextEditingController(text: 'g');
    final category = TextEditingController(text: 'Food');
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add ingredient'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Ingredient name',
                    hintText: 'Chicken, maida, oil...',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: unit,
                  decoration: const InputDecoration(
                    labelText: 'Stock unit',
                    hintText: 'g, ml, pcs, kg',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a unit' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: category,
                  decoration: const InputDecoration(
                    labelText: 'Ingredient category',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, form.currentState?.validate() ?? false),
            child: const Text('Add ingredient'),
          ),
        ],
      ),
    );
    if (saved == true) {
      try {
        await _repository.createIngredient(
          name: name.text,
          unit: unit.text.trim(),
          category: category.text.trim().isEmpty
              ? 'General'
              : category.text.trim(),
        );
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${name.text.trim()} added to ingredient list.'),
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not add ingredient: $e')),
          );
      }
    }
    name.dispose();
    unit.dispose();
    category.dispose();
  }

  Future<void> _openingStock() async {
    final chicken = TextEditingController(
      text: (_find('chicken')?.stockQuantity ?? 0).toStringAsFixed(0),
    );
    final fries = TextEditingController(
      text: (_find('fries')?.stockQuantity ?? 0).toStringAsFixed(0),
    );
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Opening stock'),
        content: SizedBox(
          width: 390,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the physical quantity available before service starts. Saving replaces the current balance.',
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: chicken,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Chicken (grams)',
                  ),
                  validator: _validate,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: fries,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Fries (grams)'),
                  validator: _validate,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, form.currentState?.validate() ?? false),
            child: const Text('Save opening stock'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _repository.setOpeningStock(
          ingredientId: 'chicken',
          name: 'Chicken',
          unit: 'g',
          quantity: double.parse(chicken.text),
        );
        await _repository.setOpeningStock(
          ingredientId: 'fries',
          name: 'Fries',
          unit: 'g',
          quantity: double.parse(fries.text),
        );
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Opening stock saved.')));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save opening stock: $e')),
          );
      }
    }
    chicken.dispose();
    fries.dispose();
  }

  Future<void> _addStock(Ingredient item) async {
    final quantity = TextEditingController();
    final cost = TextEditingController(text: '0');
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add ${item.name} stock'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Quantity (${item.baseUnit})',
                ),
                validator: _validate,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: cost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Total purchase cost (₹)',
                ),
                validator: _validate,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, form.currentState?.validate() ?? false),
            child: const Text('Add stock'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _repository.addStock(
          ingredientId: item.id,
          quantity: double.parse(quantity.text),
          totalCost: double.parse(cost.text),
        );
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Stock added.')));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Could not add stock: $e')));
      }
    }
    quantity.dispose();
    cost.dispose();
  }

  String? _validate(String? value) {
    final n = double.tryParse(value?.trim() ?? '');
    if (n == null || n < 0) return 'Enter a valid number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final chicken = _find('chicken'), fries = _find('fries');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Opening stock, purchases and current ingredient balances',
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _createIngredient,
                icon: const Icon(Icons.add),
                label: const Text('Add Ingredient'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _openingStock,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Set Opening Stock'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StockCard(
                  name: 'Chicken',
                  item: chicken,
                  onAdd: chicken == null ? null : () => _addStock(chicken),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StockCard(
                  name: 'Fries',
                  item: fries,
                  onAdd: fries == null ? null : () => _addStock(fries),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'All ingredients',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_error != null) Text('Could not load inventory: $_error'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(
                    child: Text(
                      'No stock entered. Use Set Opening Stock to get started.',
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(item.name),
                        subtitle: Text(
                          'Average cost: ₹${item.averageUnitCost.toStringAsFixed(2)} per ${item.baseUnit}',
                        ),
                        trailing: Text(
                          '${item.stockQuantity.toStringAsFixed(0)} ${item.baseUnit}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onTap: () => _addStock(item),
                      );
                    },
                  ),
          ),
          const Text(
            'Opening stock is recorded as a stock adjustment. Purchases increase the balance and update average unit cost.',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({
    required this.name,
    required this.item,
    required this.onAdd,
  });
  final String name;
  final Ingredient? item;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                tooltip: 'Add purchase',
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${(item?.stockQuantity ?? 0).toStringAsFixed(0)} ${item?.baseUnit ?? 'g'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            item == null ? 'Opening stock not set' : 'Current stock',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}
