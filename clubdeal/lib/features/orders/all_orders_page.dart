import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/order_bloc.dart';
import '../../core/bloc/menu_bloc.dart';
import '../../core/models/order_model.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_widgets.dart';

class AllOrdersPage extends StatefulWidget {
  const AllOrdersPage({super.key});

  @override
  State<AllOrdersPage> createState() => _AllOrdersPageState();
}

class _AllOrdersPageState extends State<AllOrdersPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final tableController = TextEditingController(text: 'main');
  final noteController = TextEditingController();

  final Map<String, int> selected = {};

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    tableController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderBloc, OrderState>(
      builder: (context, orderState) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              PageTitle(
                title: 'All Orders',
                subtitle: 'Order history and manual order entry',
                trailing: FilledButton.icon(
                  onPressed: () => _showManualOrder(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Manual Order'),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: orderState.orders.isEmpty
                    ? const EmptyPanel(
                        title: 'No orders',
                        message: 'Orders will appear here.',
                      )
                    : ListView.separated(
                        itemCount: orderState.orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, index) {
                          final order = orderState.orders[index];
                          return _HistoryRow(order: order);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showManualOrder(BuildContext context) async {
    selected.clear();
    nameController.clear();
    phoneController.clear();
    tableController.text = 'main';
    noteController.clear();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Manual Order'),
          content: SizedBox(
            width: 720,
            height: 560,
            child: BlocBuilder<MenuBloc, MenuState>(
              builder: (context, menuState) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Customer name',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: tableController,
                            decoration: const InputDecoration(
                              labelText: 'Table',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Note'),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.builder(
                        itemCount: menuState.items.length,
                        itemBuilder: (_, index) {
                          final item = menuState.items[index];
                          final qty = selected[item.id] ?? 0;

                          return ListTile(
                            dense: true,
                            title: Text(item.name),
                            subtitle: Text(
                              '₹${item.price.toStringAsFixed(0)}  •  ${item.category}',
                            ),
                            leading: Text(
                              item.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            trailing: SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed: qty <= 0
                                        ? null
                                        : () => setState(
                                            () => selected[item.id] = qty - 1,
                                          ),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text('$qty'),
                                  IconButton(
                                    onPressed: !item.isAvailable
                                        ? null
                                        : () => setState(
                                            () => selected[item.id] = qty + 1,
                                          ),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final menu = context.read<MenuBloc>().state.items;
                final items = <OrderItem>[];

                for (final item in menu) {
                  final qty = selected[item.id] ?? 0;
                  if (qty > 0) {
                    items.add(
                      OrderItem(
                        name: item.name,
                        qty: qty,
                        price: item.price,
                        emoji: item.emoji,
                        category: item.category,
                      ),
                    );
                  }
                }

                if (nameController.text.trim().isEmpty || items.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter customer name and select at least one item.',
                      ),
                    ),
                  );
                  return;
                }

                try {
                  await context.read<OrderBloc>().repository.createManualOrder(
                    customerName: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    table: tableController.text.trim(),
                    note: noteController.text.trim(),
                    items: items,
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              child: const Text('Create Order'),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final RestaurantOrder order;

  const _HistoryRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              '#${order.id.substring(0, order.id.length > 7 ? 7 : order.id.length)}',
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              order.customerName,
              style: const TextStyle(color: AppColors.cream),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              order.table,
              style: const TextStyle(color: AppColors.cream2),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              '${order.items.length} item(s)',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              '₹${order.total.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
