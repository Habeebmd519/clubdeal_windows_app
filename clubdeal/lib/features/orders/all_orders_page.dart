import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/order_bloc.dart';
import '../../core/bloc/menu_bloc.dart';
import '../../core/models/order_model.dart';
import '../../core/services/printer_service.dart';
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
  final itemSearchController = TextEditingController();
  final Map<String, int> selected = {};

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    tableController.dispose();
    noteController.dispose();
    itemSearchController.dispose();
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
                child: orderState.loading && orderState.orders.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : orderState.orders.isEmpty
                        ? const EmptyPanel(
                            title: 'No orders',
                            message: 'Orders will appear here.',
                          )
                        : ListView.separated(
                            itemCount: orderState.orders.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 7),
                            itemBuilder: (_, index) =>
                                _HistoryRow(order: orderState.orders[index]),
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
    itemSearchController.clear();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Add Manual Order'),
            content: SizedBox(
              width: 740,
              height: 590,
              child: BlocBuilder<MenuBloc, MenuState>(
                builder: (menuContext, menuState) {
                  final query = itemSearchController.text.trim().toLowerCase();
                  final visibleItems = menuState.items.where((item) {
                    return query.isEmpty ||
                        item.name.toLowerCase().contains(query) ||
                        item.category.toLowerCase().contains(query) ||
                        item.tag.toLowerCase().contains(query);
                  }).toList();

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameController,
                              decoration: const InputDecoration(labelText: 'Customer name'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              decoration: const InputDecoration(labelText: 'Phone'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 130,
                            child: TextField(
                              controller: tableController,
                              decoration: const InputDecoration(labelText: 'Table'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(labelText: 'Note'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: itemSearchController,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search menu items by name or category...',
                          prefixIcon: const Icon(Icons.search, size: 19),
                          suffixIcon: itemSearchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    itemSearchController.clear();
                                    setDialogState(() {});
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${visibleItems.length} menu item(s) • ${selected.values.fold<int>(0, (a, b) => a + b)} selected',
                          style: const TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: visibleItems.isEmpty
                            ? const Center(
                                child: Text('No matching menu items.',
                                    style: TextStyle(color: AppColors.muted)),
                              )
                            : ListView.builder(
                                itemCount: visibleItems.length,
                                itemBuilder: (_, index) {
                                  final item = visibleItems[index];
                                  final qty = selected[item.id] ?? 0;
                                  return ListTile(
                                    dense: true,
                                    title: Text(item.name),
                                    subtitle: Text(
                                      '₹${item.price.toStringAsFixed(2)} • ${item.category}${item.isAvailable ? '' : ' • Unavailable'}',
                                    ),
                                    leading: Text(item.emoji, style: const TextStyle(fontSize: 22)),
                                    trailing: SizedBox(
                                      width: 124,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            tooltip: 'Remove one',
                                            onPressed: qty <= 0
                                                ? null
                                                : () => setDialogState(() {
                                                      final next = qty - 1;
                                                      if (next == 0) {
                                                        selected.remove(item.id);
                                                      } else {
                                                        selected[item.id] = next;
                                                      }
                                                    }),
                                            icon: const Icon(Icons.remove_circle_outline),
                                          ),
                                          Text('$qty'),
                                          IconButton(
                                            tooltip: 'Add one',
                                            onPressed: !item.isAvailable
                                                ? null
                                                : () => setDialogState(() {
                                                      selected[item.id] = qty + 1;
                                                    }),
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
              FilledButton.icon(
                onPressed: () async {
                  final menu = context.read<MenuBloc>().state.items;
                  final items = <OrderItem>[];
                  for (final item in menu) {
                    final qty = selected[item.id] ?? 0;
                    if (qty > 0) {
                      items.add(OrderItem(
                        name: item.name,
                        qty: qty,
                        price: item.price,
                        emoji: item.emoji,
                        category: item.category,
                      ));
                    }
                  }
                  if (nameController.text.trim().isEmpty || items.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter customer name and select at least one item.')),
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
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create order: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.add_task, size: 17),
                label: const Text('Create Order'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final RestaurantOrder order;
  const _HistoryRow({required this.order});

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool expanded = false;
  bool printing = false;

  Future<void> _print(BuildContext context) async {
    setState(() => printing = true);
    try {
      await context.read<PrinterService>().printOrder(widget.order);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill sent to printer.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 95,
                    child: Text(
                      '#${order.id.substring(0, order.id.length > 7 ? 7 : order.id.length)}',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: Text(order.customerName, style: const TextStyle(color: AppColors.cream))),
                  SizedBox(width: 100, child: Text(order.table, style: const TextStyle(color: AppColors.cream2))),
                  SizedBox(width: 100, child: Text('${order.items.length} item(s)', style: const TextStyle(color: AppColors.muted))),
                  SizedBox(
                    width: 110,
                    child: Text('₹${order.total.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Print bill',
                    visualDensity: VisualDensity.compact,
                    onPressed: printing ? null : () => _print(context),
                    icon: printing
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.print_outlined, size: 18),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.muted),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    children: [
                      Text('Customer: ${order.customerName}', style: const TextStyle(color: AppColors.cream2, fontSize: 12)),
                      Text('Phone: ${order.phone.isEmpty ? '—' : order.phone}', style: const TextStyle(color: AppColors.cream2, fontSize: 12)),
                      Text('Status: ${order.status.name.toUpperCase()}', style: const TextStyle(color: AppColors.cream2, fontSize: 12)),
                    ],
                  ),
                  if (order.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Note: ${order.note}', style: const TextStyle(color: AppColors.cream2, fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(item.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.name, style: const TextStyle(color: AppColors.cream, fontSize: 12))),
                        Text('x${item.qty}', style: const TextStyle(color: AppColors.cream2, fontSize: 12)),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 100,
                          child: Text('₹${item.total.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: AppColors.cream, fontSize: 12)),
                        ),
                      ],
                    ),
                  )),
                  const Divider(color: AppColors.border),
                  Row(
                    children: [
                      Text('Total: ₹${order.total.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: printing ? null : () => _print(context),
                        icon: printing
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.print_outlined, size: 17),
                        label: Text(printing ? 'Printing…' : 'Print Bill'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
