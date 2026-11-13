import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/menu_bloc.dart';
import '../../core/models/menu_item.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/repositories/inventory_repository.dart';
import '../../core/repositories/restaurant_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_widgets.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuBloc, MenuState>(
      builder: (context, state) {
        final items = state.items.where((item) {
          final q = query.toLowerCase().trim();
          return q.isEmpty ||
              item.name.toLowerCase().contains(q) ||
              item.category.toLowerCase().contains(q) ||
              item.tag.toLowerCase().contains(q);
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              PageTitle(
                title: 'Menu',
                subtitle: 'Manage items, prices and availability',
                trailing: Row(
                  children: [
                    SizedBox(
                      width: 250,
                      child: TextField(
                        onChanged: (v) => setState(() => query = v),
                        decoration: const InputDecoration(
                          hintText: 'Search menu...',
                          prefixIcon: Icon(Icons.search, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _editItem(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: state.loading
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? const EmptyPanel(
                            title: 'No menu items',
                            message: 'Add your first item.',
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, index) {
                              final item = items[index];
                              return _MenuRow(
                                item: item,
                                onEdit: () => _editItem(context, item),
                                onDelete: () => _delete(context, item),
                                onAvailability: (value) {
                                  context.read<MenuBloc>().add(
                                        MenuAvailabilityChanged(
                                          item.id,
                                          value,
                                        ),
                                      );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(
    BuildContext context,
    MenuItemModel item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Delete "${item.name}" from the menu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      context.read<MenuBloc>().add(MenuItemDeleted(item.id));
    }
  }

  Future<void> _editItem(
    BuildContext context, [
    MenuItemModel? old,
  ]) async {
    final name = TextEditingController(text: old?.name ?? '');
    final price = TextEditingController(
      text: old == null ? '' : old.price.toString(),
    );
    final category = TextEditingController(text: old?.category ?? '');
    final description = TextEditingController(text: old?.description ?? '');
    final emoji = TextEditingController(text: old?.emoji ?? '🍽️');
    final tag = TextEditingController(text: old?.tag ?? '');
    final recipeQuantities = <String, double>{};
    for (final line in old?.recipeLines ?? const <Map<String, dynamic>>[]) {
      final id = (line['ingredientId'] ?? '').toString();
      final quantity = (line['quantity'] as num?)?.toDouble() ?? 0;
      if (id.isNotEmpty && quantity > 0) recipeQuantities[id] = quantity;
    }
    bool available = old?.isAvailable ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(old == null ? 'Add Menu Item' : 'Edit Menu Item'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: price,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Price',
                                prefixText: '₹ ',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: category,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: description,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: emoji,
                              decoration: const InputDecoration(
                                labelText: 'Emoji',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: tag,
                              decoration: const InputDecoration(
                                labelText: 'Tag',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Recipe / Ingredients per item',
                          style: Theme.of(context).textTheme.titleMedium),
                      ),
                      const SizedBox(height: 6),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Choose ingredients already added in Inventory and enter the quantity used for ONE menu item.',
                          style: TextStyle(fontSize: 11, color: Colors.white60)),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<Ingredient>>(
                        stream: InventoryRepository(FirebaseFirestore.instance).watchIngredients(),
                        builder: (context, ingredientSnapshot) {
                          final ingredients = ingredientSnapshot.data ?? const <Ingredient>[];
                          final selectedIds = recipeQuantities.keys.toList();
                          return Column(
                            children: [
                              if (ingredientSnapshot.hasError)
                                Text('Could not load ingredients: ${ingredientSnapshot.error}'),
                              if (ingredients.isEmpty && !ingredientSnapshot.hasError)
                                const Align(alignment: Alignment.centerLeft, child: Text('Add ingredients in Inventory first.', style: TextStyle(color: Colors.orange, fontSize: 12))),
                              ...selectedIds.map((id) {
                                final selected = ingredients.where((i) => i.id == id).toList();
                                final current = selected.isEmpty ? null : selected.first;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(children: [
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<String>(
                                        value: current?.id,
                                        isExpanded: true,
                                        decoration: const InputDecoration(labelText: 'Ingredient'),
                                        items: ingredients.map((ingredient) => DropdownMenuItem(
                                          value: ingredient.id,
                                          child: Text('${ingredient.name} (${ingredient.baseUnit})'),
                                        )).toList(),
                                        onChanged: (value) {
                                          if (value == null || value == id) return;
                                          setDialogState(() {
                                            final quantity = recipeQuantities.remove(id) ?? 0;
                                            recipeQuantities[value] = quantity;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        key: ValueKey('recipe-$id-${recipeQuantities[id]}'),
                                        initialValue: recipeQuantities[id]!.toString(),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(labelText: 'Qty per item', suffixText: current?.baseUnit ?? ''),
                                        onChanged: (value) {
                                          final quantity = double.tryParse(value);
                                          if (quantity != null && quantity >= 0) recipeQuantities[id] = quantity;
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove ingredient',
                                      onPressed: () => setDialogState(() => recipeQuantities.remove(id)),
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                    ),
                                  ]),
                                );
                              }),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: ingredients.isEmpty || ingredients.every((i) => recipeQuantities.containsKey(i.id))
                                      ? null
                                      : () => setDialogState(() {
                                          final next = ingredients.firstWhere((i) => !recipeQuantities.containsKey(i.id));
                                          recipeQuantities[next.id] = 0;
                                        }),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Ingredient'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Available'),
                        value: available,
                        onChanged: (v) {
                          setDialogState(() => available = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final itemName = name.text.trim();
                    final itemPrice =
                        double.tryParse(price.text.trim()) ?? 0;

                    if (itemName.isEmpty || itemPrice <= 0 || recipeQuantities.values.any((quantity) => quantity < 0)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid name and price.'),
                        ),
                      );
                      return;
                    }

                    await context
                        .read<MenuBloc>()
                        .repository
                        .saveMenuItem(
                          id: old?.id,
                          name: itemName,
                          price: itemPrice,
                          category: category.text.trim().isEmpty
                              ? 'Other'
                              : category.text.trim(),
                          description: description.text.trim(),
                          emoji: emoji.text.trim(),
                          tag: tag.text.trim(),
                          isAvailable: available,
                          recipeLines: recipeQuantities.entries
                              .where((entry) => entry.value > 0)
                              .map((entry) => {'ingredientId': entry.key, 'quantity': entry.value})
                              .toList(),
                        );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: Text(old == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    name.dispose();
    price.dispose();
    category.dispose();
    description.dispose();
    emoji.dispose();
    tag.dispose();
  }
}

class _MenuRow extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onAvailability;

  const _MenuRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onAvailability,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: Text(
              item.emoji,
              style: const TextStyle(fontSize: 23),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              item.name,
              style: const TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.category,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              '₹${item.price.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Switch(
              value: item.isAvailable,
              onChanged: onAvailability,
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.error,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
