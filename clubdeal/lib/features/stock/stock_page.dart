import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/bloc/stock_bloc.dart';
import '../../core/models/stock_model.dart';
// import '../../core/models/stock_transaction_model.dart';
import 'stock_forms.dart';
import 'stock_details_page.dart';

class Stock extends StatefulWidget {
  const Stock({super.key});

  @override
  State<Stock> createState() => _StockState();
}

class _StockState extends State<Stock> {
  String query = '';

  @override
  void initState() {
    super.initState();
    context.read<StockBloc>().add(LoadStocks());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StockBloc, StockState>(
      builder: (context, state) {
        final items =
            state.items
                .where(
                  (s) =>
                      s.name.toLowerCase().contains(query.toLowerCase()) ||
                      s.category.toLowerCase().contains(query.toLowerCase()),
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

        final low = state.items.where((e) => e.isLowStock).length;
        final out = state.items.where((e) => e.isOutOfStock).length;
        final value = state.items.fold<double>(
          0,
          (sum, e) => sum + e.stockValue,
        );

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock Management',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Track inventory, purchases and daily usage',
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openForm(context, const UseStockForm()),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Record Usage'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openForm(context, const PurchaseStockForm()),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    label: const Text('Purchase'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openForm(context, const AddStockForm()),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Stock'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    title: 'Stock items',
                    value: '${state.items.length}',
                    icon: Icons.inventory_2_outlined,
                  ),
                  _Metric(
                    title: 'Stock value',
                    value: NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                      decimalDigits: 2,
                    ).format(value),
                    icon: Icons.currency_rupee,
                  ),
                  _Metric(
                    title: 'Low stock',
                    value: '$low',
                    icon: Icons.warning_amber_outlined,
                  ),
                  _Metric(
                    title: 'Out of stock',
                    value: '$out',
                    icon: Icons.remove_shopping_cart_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 320,
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: 'Search stock or category',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () => setState(() => query = ''),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MaterialBanner(
                    content: Text(state.error!),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            context.read<StockBloc>().add(LoadStocks()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: state.loading && state.items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                    ? const Center(
                        child: Text(
                          'No stock items yet. Add your first stock item.',
                        ),
                      )
                    : Card(
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Icon(
                                  item.isOutOfStock
                                      ? Icons.error_outline
                                      : item.isLowStock
                                      ? Icons.warning_amber
                                      : Icons.inventory_2_outlined,
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${item.category} • ${_status(item)} • Low-stock alert at ${item.lowStockThreshold} ${item.unit}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item.quantity.toStringAsFixed(2)} ${item.unit}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const Text('Remaining', style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                  IconButton(
                                    tooltip: 'Delete stock item',
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _confirmDelete(context, item),
                                  ),
                                ],
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StockDetailsPage(item: item),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _status(StockItem item) => item.isOutOfStock
      ? 'Out of stock'
      : item.isLowStock
      ? 'Low stock'
      : 'Available';

  Future<void> _openForm(BuildContext context, Widget form) async {
    await showDialog(context: context, builder: (_) => form);
    if (mounted) context.read<StockBloc>().add(LoadStocks());
  }

  Future<void> _confirmDelete(BuildContext context, StockItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete stock item?'),
        content: Text('Delete "${item.name}" from Firestore? Its stock movement history will also be deleted. Menu recipes that use it must be updated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<StockBloc>().add(DeleteStock(item.id));
    }
  }
}

class _Metric extends StatelessWidget {
  final String title, value;
  final IconData icon;
  const _Metric({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 26,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
