import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bloc/menu_bloc.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuBloc, MenuState>(
      builder: (context, state) {
        final chicken = state.items.fold<double>(0, (sum, item) => sum + item.chickenGrams);
        final fries = state.items.fold<double>(0, (sum, item) => sum + item.friesGrams);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Inventory', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            const Text('Ingredient usage configured on menu items in Firestore menu2'),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _Metric(title: 'Menu items', value: '${state.items.length}', icon: Icons.restaurant_menu)),
              const SizedBox(width: 12),
              Expanded(child: _Metric(title: 'Chicken recipe total', value: '${chicken.toStringAsFixed(0)} g', icon: Icons.set_meal)),
              const SizedBox(width: 12),
              Expanded(child: _Metric(title: 'Fries recipe total', value: '${fries.toStringAsFixed(0)} g', icon: Icons.fastfood)),
            ]),
            const SizedBox(height: 18),
            Expanded(child: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
                ? Center(child: Text('Could not load menu2 ingredient usage: ${state.error}'))
                : Card(child: Column(children: [
                    const ListTile(title: Text('Ingredient usage per menu item', style: TextStyle(fontWeight: FontWeight.w700))),
                    const Divider(height: 1),
                    Expanded(child: ListView.separated(
                      itemCount: state.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        return ListTile(
                          leading: Text(item.emoji, style: const TextStyle(fontSize: 22)),
                          title: Text(item.name),
                          subtitle: Text('Chicken: ${item.chickenGrams.toStringAsFixed(0)} g  ·  Fries: ${item.friesGrams.toStringAsFixed(0)} g'),
                          trailing: Text(item.isAvailable ? 'Available' : 'Unavailable', style: TextStyle(color: item.isAvailable ? Colors.green : Colors.orange)),
                        );
                      },
                    )),
                  ])),
            ),
            const SizedBox(height: 8),
            const Text('Note: this page shows recipe usage, not live on-hand stock. Purchase and stock deduction workflows must be configured before displaying stock balances.', style: TextStyle(fontSize: 11, color: Colors.white60)),
          ]),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.icon});
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Icon(icon, size: 26, color: Theme.of(context).colorScheme.secondary),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ])),
    ]),
  ));
}
