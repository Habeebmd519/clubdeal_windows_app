import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/bloc/order_bloc.dart';
import '../../core/bloc/menu_bloc.dart';
import '../../core/models/order_model.dart';
import '../../core/services/printer_service.dart';
import '../../core/services/customer_display_service.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_widgets.dart';

class OrderTile extends StatefulWidget {
  final RestaurantOrder order;
  const OrderTile({super.key, required this.order});
  @override
  State<OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends State<OrderTile> {
  bool expanded = false, printing = false;

  Future<void> _print() async {
    setState(() => printing = true);
    try {
      await context.read<PrinterService>().printOrder(widget.order);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bill sent to printer.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Print failed: $e')));
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  Future<void> _complete() async {
    PaymentMethod method = PaymentMethod.cash;
    final selected = await showDialog<PaymentMethod>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Complete order & record payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Order total: ₹${widget.order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              for (final m in PaymentMethod.values)
                RadioListTile<PaymentMethod>(
                  value: m,
                  groupValue: method,
                  title: Text(_paymentLabel(m)),
                  onChanged: (v) {
                    if (v != null) setStateDialog(() => method = v);
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, method),
              child: const Text('Confirm payment'),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      try {
        await context.read<OrderBloc>().repository.deliverOrder(
          widget.order.id,
          selected,
        );
        // Customer-display errors must never block a saved payment.
        try {
          await context.read<CustomerDisplayService>().showPayment(widget.order.total);
        } catch (_) {}
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment could not be saved: $e')),
          );
        return;
      }
      try {
        await context.read<PrinterService>().printOrder(
          widget.order,
          paymentMethod: selected,
        );
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment saved and bill printed.')),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment saved. Bill printing failed: $e')),
          );
      }
    }
  }

  Future<void> _cancel() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel order?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason for cancellation',
            hintText: 'Customer changed mind, item unavailable...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              controller.text.trim().isEmpty
                  ? 'No reason provided'
                  : controller.text.trim(),
            ),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null && mounted)
      context.read<OrderBloc>().add(OrderCancelled(widget.order.id, reason));
  }

  Future<void> _edit() async {
    final order = widget.order;
    final name = TextEditingController(text: order.customerName);
    final phone = TextEditingController(text: order.phone);
    final table = TextEditingController(text: order.table);
    final note = TextEditingController(text: order.note);
    final form = GlobalKey<FormState>();
    final menuItems = context.read<MenuBloc>().state.items;
    final editItems = order.items
        .map((i) => OrderItem(
              name: i.name,
              qty: i.qty,
              price: i.price,
              emoji: i.emoji,
              category: i.category,
            ))
        .toList();
    String? selectedMenuId;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit order'),
          content: SizedBox(
            width: 620,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Customer name'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a name'
                          : null,
                    ),
                    TextFormField(
                      controller: phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    TextFormField(
                      controller: table,
                      decoration:
                          const InputDecoration(labelText: 'Table / token'),
                    ),
                    TextFormField(
                      controller: note,
                      decoration:
                          const InputDecoration(labelText: 'Order note'),
                    ),
                    const Divider(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Items and quantities',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(editItems.length, (i) {
                      final item = editItems[i];
                      return Row(
                        children: [
                          Expanded(child: Text('${item.emoji} ${item.name}')),
                          SizedBox(
                            width: 85,
                            child: TextFormField(
                              key: ValueKey('edit_order_qty_$i'),
                              initialValue: '${item.qty}',
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Qty'),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                return n == null || n < 0 ? 'Invalid' : null;
                              },
                              onChanged: (v) {
                                final n = int.tryParse(v);
                                if (n != null) {
                                  editItems[i] = OrderItem(
                                    name: item.name,
                                    qty: n,
                                    price: item.price,
                                    emoji: item.emoji,
                                    category: item.category,
                                  );
                                }
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove item',
                            onPressed: () =>
                                setDialogState(() => editItems.removeAt(i)),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedMenuId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Add menu item',
                            ),
                            items: menuItems
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m.id,
                                    child: Text(
                                      '${m.name} • ₹${m.price.toStringAsFixed(2)}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedMenuId = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: selectedMenuId == null
                              ? null
                              : () {
                                  final menu = menuItems.firstWhere(
                                    (m) => m.id == selectedMenuId,
                                  );
                                  final index = editItems.indexWhere(
                                    (i) => i.name == menu.name,
                                  );
                                  setDialogState(() {
                                    if (index >= 0) {
                                      final old = editItems[index];
                                      editItems[index] = OrderItem(
                                        name: old.name,
                                        qty: old.qty + 1,
                                        price: old.price,
                                        emoji: old.emoji,
                                        category: old.category,
                                      );
                                    } else {
                                      editItems.add(OrderItem(
                                        name: menu.name,
                                        qty: 1,
                                        price: menu.price,
                                        emoji: menu.emoji,
                                        category: menu.category,
                                      ));
                                    }
                                    selectedMenuId = null;
                                  });
                                },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, form.currentState?.validate() ?? false),
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final updated = editItems.where((i) => i.qty > 0).toList();
      if (updated.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An order must have at least one item.'),
          ),
        );
      } else {
        context.read<OrderBloc>().add(OrderEdited(
              orderId: order.id,
              customerName: name.text.trim(),
              phone: phone.text.trim(),
              table: table.text.trim(),
              note: note.text.trim(),
              items: updated,
            ));
      }
    }
    name.dispose();
    phone.dispose();
    table.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final next = _nextStatus(order.status);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () {
              final opening = !expanded;
              setState(() => expanded = opening);
              if (opening) {
                // The desktop app receives saved orders rather than a live
                // checkout cart; show the selected order on the customer VFD.
                context.read<CustomerDisplayService>().showOrder(widget.order)
                    .catchError((Object _) {});
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(
                      '#${order.id.substring(0, order.id.length > 6 ? 6 : order.id.length)}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      order.customerName,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 85,
                    child: Text(
                      order.table,
                      style: const TextStyle(color: AppColors.cream2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${order.items.length} item(s) • ${DateFormat('hh:mm a').format(order.createdAt ?? DateTime.now())}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusPill(
                    text: order.status.name.toUpperCase(),
                    color: _statusColor(order.status),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: Text(
                      '₹${order.total.toStringAsFixed(0)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Print bill',
                    onPressed: printing ? null : _print,
                    icon: printing
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined, size: 18),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    children: [
                      Text(
                        'Customer: ${order.customerName}',
                        style: const TextStyle(
                          color: AppColors.cream2,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Phone: ${order.phone.isEmpty ? '—' : order.phone}',
                        style: const TextStyle(
                          color: AppColors.cream2,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Table: ${order.table}',
                        style: const TextStyle(
                          color: AppColors.cream2,
                          fontSize: 12,
                        ),
                      ),
                      if (order.paymentMethod != null)
                        Text(
                          'Paid by: ${_paymentLabel(order.paymentMethod!)}',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  if (order.note.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        'Note: ${order.note}',
                        style: const TextStyle(
                          color: AppColors.cream2,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (order.status == OrderStatus.cancelled &&
                      order.cancelReason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        'Cancellation reason: ${order.cancelReason}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  ...order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(item.emoji),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                color: AppColors.cream,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            'x${item.qty}',
                            style: const TextStyle(
                              color: AppColors.cream2,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 90,
                            child: Text(
                              '₹${item.total.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: AppColors.cream2,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.border),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: printing ? null : _print,
                        icon: const Icon(Icons.print_outlined, size: 17),
                        label: const Text('Print Bill'),
                      ),
                      if (order.status != OrderStatus.delivered &&
                          order.status != OrderStatus.cancelled) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _edit,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _cancel,
                          icon: const Icon(
                            Icons.cancel_outlined,
                            size: 16,
                            color: AppColors.error,
                          ),
                          label: const Text(
                            'Cancel',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (order.status == OrderStatus.ready)
                        FilledButton.icon(
                          onPressed: _complete,
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          label: const Text('Take Payment & Deliver'),
                        )
                      else if (next != null)
                        FilledButton.icon(
                          onPressed: () => context.read<OrderBloc>().add(
                            OrderStatusChanged(order.id, next),
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text('Mark ${next.name}'),
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

  OrderStatus? _nextStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.ready;
      case OrderStatus.ready:
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return null;
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.preparing:
        return AppColors.info;
      case OrderStatus.ready:
        return AppColors.success;
      case OrderStatus.delivered:
        return AppColors.green;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }
}

String _paymentLabel(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return 'Cash';
    case PaymentMethod.card:
      return 'Card';
    case PaymentMethod.online:
      return 'Online / UPI';
  }
}
